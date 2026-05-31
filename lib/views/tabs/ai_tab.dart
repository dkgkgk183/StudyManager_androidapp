import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../viewmodels/study_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../services/api_key_service.dart';
import '../../database/database.dart';
import '../../main.dart' show database;

const String _kChecklistPrefix = 'checklist_chat_';

// ── 체크리스트 데이터 모델 ────────────────────────────────
class _ChecklistData {
  final String subjectName;
  final String text;

  _ChecklistData({required this.subjectName, required this.text});
}

// ── 채팅 메시지 모델 ──────────────────────────────────────
class _ChatMessage {
  final bool isAi;
  String text;
  bool isError;
  List<_ChecklistData>? checklists;
  bool checklistsAdded;
  bool isStreaming;
  String? toolStatus;

  _ChatMessage({
    required this.isAi,
    required this.text,
    this.isError = false,
    this.checklists,
    this.checklistsAdded = false,
    this.isStreaming = false,
    this.toolStatus,
  });
}

// ── 저장된 세션 정보 ──────────────────────────────────────
class _SessionInfo {
  final String key;       // SharedPreferences 키
  final DateTime date;
  final int messageCount; // 사용자 메시지 수

  _SessionInfo({
    required this.key,
    required this.date,
    required this.messageCount,
  });

  String get label => DateFormat('M월 d일', 'ko').format(date);
}

// ── JSON 파싱 유틸 ────────────────────────────────────────
class AiTab extends ConsumerStatefulWidget {
  const AiTab({super.key});

  @override
  ConsumerState<AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<AiTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  DateTime _selectedDate = DateTime.now();

  String _rangeKey() =>
      '$_kChecklistPrefix${DateFormat('yyyy-MM-dd').format(_selectedDate)}';

  final Map<String, List<_ChatMessage>> _checklistMessagesCache = {};
  final Map<String, List<Map<String, dynamic>>> _checklistHistoryCache = {};

  List<_ChatMessage> _checklistMessages() {
    final key = _rangeKey();
    return _checklistMessagesCache.putIfAbsent(key, () => [
      _ChatMessage(isAi: true, text:
      '안녕하세요! 공부 체크리스트를 정리해드릴게요.\n\n오늘 할 공부 내용을 편하게 말씀해 주시면 과목별로 깔끔한 체크리스트로 정리해 드려요.\n\n예시:\n"수학 미적분 연습하고 영어 단어 50개 외워야 해"\n"오늘 할 공부 정리해줘"'),
    ]);
  }

  List<Map<String, dynamic>> _checklistHistory() {
    final key = _rangeKey();
    return _checklistHistoryCache.putIfAbsent(key, () => []);
  }

  bool _isLoading = false;
  bool _isDataLoaded = false;

  // ── 사이드바 세션 목록 ────────────────────────────────
  List<_SessionInfo> _savedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            setState(() => _isListening = false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_controller.text.trim().isNotEmpty) {
                _sendMessage();
              }
            });
          }
        }
      },
    );
    setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 인식을 사용할 수 없어요. 마이크 권한을 확인해주세요.')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
      );
    }
  }

  // ── 날짜 스와이프 ─────────────────────────────────────
  void _swipeDate(int days) async {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    await _loadChecklistDataForRange();
    if (mounted) setState(() {});
  }

  // ── 체크리스트 파싱 ──────────────────────────────────────
  List<_ChecklistData> _parseChecklistsFromText(String text) {
    final results = <_ChecklistData>[];
    final lines = text.split('\n');
    String? currentSubject;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 과목 헤더: **과목명** 또는 ## 과목명
      final boldMatch = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(trimmed);
      final h2Match = RegExp(r'^##\s+(.+)$').firstMatch(trimmed);
      if (boldMatch != null) {
        currentSubject = boldMatch.group(1)!.trim();
        continue;
      }
      if (h2Match != null) {
        currentSubject = h2Match.group(1)!.trim();
        continue;
      }

      // 체크리스트 항목: "- [ ] text" 또는 "- text"
      final checkMatch = RegExp(r'^-\s+\[\s?\]\s*(.+)$').firstMatch(trimmed);
      final dashMatch = RegExp(r'^-\s+(.+)$').firstMatch(trimmed);
      final itemText = checkMatch?.group(1) ?? dashMatch?.group(1);
      if (itemText != null && currentSubject != null) {
        results.add(_ChecklistData(
          subjectName: currentSubject,
          text: itemText.trim(),
        ));
      }
    }

    return results;
  }

  // ── 체크리스트 추가 ──────────────────────────────────────
  Future<void> _addChecklists(int messageIndex) async {
    final messages = _checklistMessages();
    if (messageIndex >= messages.length) return;

    final aiResponse = messages[messageIndex].text;
    if (aiResponse.isEmpty) return;

    final items = _parseChecklistsFromText(aiResponse);
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('체크리스트를 추출할 수 없어요. 다시 시도해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final allSubjects = await database.getAllSubjects();

    final aiItems = <Map<String, dynamic>>[];
    final errors = <String>[];

    for (final item in items) {
      final matched = allSubjects.where((s) =>
      s.name.contains(item.subjectName) ||
          item.subjectName.contains(s.name)).toList();

      if (matched.isEmpty) {
        errors.add('"${item.subjectName}" 과목을 찾을 수 없어요');
        continue;
      }

      aiItems.add({
        'subjectId': matched.first.id,
        'text': item.text,
      });
    }

    if (aiItems.isNotEmpty) {
      // 기존 체크리스트 확인
      final existing = await ref.read(todayChecklistViewModelProvider(_selectedDate).future);

      if (existing.isNotEmpty && mounted) {
        // 기존 항목이 있으면 팝업 표시
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('체크리스트가 이미 있어요'),
            content: Text(
              '오늘 날짜에 ${existing.length}개의 체크리스트가 있습니다.\n'
              '새로운 항목을 어떻게 추가할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'overwrite'),
                child: const Text('덮어쓰기', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'add'),
                child: const Text('추가'),
              ),
            ],
          ),
        );

        if (action == 'cancel' || action == null) return;

        if (action == 'overwrite') {
          await ref.read(todayChecklistViewModelProvider(_selectedDate).notifier)
              .deleteAll();
        }
        // action == 'add'면 기존 항목 유지 + 추가
      }

      await ref.read(todayChecklistViewModelProvider(_selectedDate).notifier)
          .addItemsFromAI(aiItems);
    }

    // 오늘 탭과 날짜 동기화 + provider 갱신
    ref.read(selectedDateProvider.notifier).setDate(_selectedDate);
    ref.invalidate(todayChecklistViewModelProvider(_selectedDate));

    setState(() {
      final msgs = _checklistMessages();
      if (messageIndex < msgs.length) {
        msgs[messageIndex].checklistsAdded = true;
      }
    });

    if (!mounted) return;
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${aiItems.length}개의 체크리스트가 추가됐어요'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${aiItems.length}개 추가, ${errors.join(' / ')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ── AI 응답 다시 생성 ─────────────────────────────────
  Future<void> _regenerateResponse(int aiMessageIndex) async {
    final currentMessages = _checklistMessages();
    final currentHistory = _checklistHistory();

    // AI 메시지 유효성 확인
    if (aiMessageIndex < 0 || aiMessageIndex >= currentMessages.length) return;
    if (!currentMessages[aiMessageIndex].isAi) return;

    // 앞의 사용자 메시지 찾기
    if (aiMessageIndex == 0) return; // 첫 AI 인사말은 재생성 불가
    final userMessage = currentMessages[aiMessageIndex - 1];
    if (userMessage.isAi) return;

    // AI 메시지 제거 & 히스토리에서 모델 응답 제거
    setState(() {
      currentMessages.removeAt(aiMessageIndex);
      // 히스토리에서 마지막 model 응답 제거
      for (int i = currentHistory.length - 1; i >= 0; i--) {
        if (currentHistory[i]['role'] == 'model') {
          currentHistory.removeAt(i);
          break;
        }
      }
    });

    await _saveChecklistData();

    // 사용자 메시지 텍스트로 재전송 (_controller에 넣지 않고 직접 처리)
    final text = userMessage.text;
    if (text.isEmpty || _isLoading) return;

    final categoryList = await ref.read(categoryViewModelProvider.future);
    final systemPrompt = _buildChecklistSystemPrompt(categoryList);

    final openRouterKey = await ref.read(openRouterApiKeyProvider.future);

    setState(() => _isLoading = true);

    // 스트리밍 응답 버블 추가
    final aiBubble = _ChatMessage(isAi: true, text: '', isStreaming: true);
    setState(() => currentMessages.add(aiBubble));

    final StringBuffer buffer = StringBuffer();
    final client = http.Client();

    try {
      if (openRouterKey != null && openRouterKey.isNotEmpty) {
        final openRouterModel =
            ref.read(openRouterModelProvider).valueOrNull ?? defaultOpenRouterModel;
        await _sendOpenRouterRequest(
          client: client,
          apiKey: openRouterKey,
          model: openRouterModel,
          systemPrompt: systemPrompt,
          text: text,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      } else {
        final serverUrl = await ref.read(serverUrlProvider.future);
        final url =
            '${serverUrl.replaceAll(RegExp(r'/+$'), '')}/v1/responses';
        await _sendHermesRequest(
          client: client,
          url: url,
          systemPrompt: systemPrompt,
          text: text,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      }

      final rawText = buffer.toString();
      if (rawText.isNotEmpty) {
        const checklistMarker = '체크리스트를 정리해드릴게요.';
        final hasChecklistMarker = rawText.contains(checklistMarker);
        final checklists = hasChecklistMarker ? <_ChecklistData>[] : null;

        setState(() {
          aiBubble.text = rawText;
          aiBubble.checklists = checklists;
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });

        currentHistory.add({'role': 'model', 'parts': [{'text': rawText}]});
        await _saveChecklistData();
      } else {
        setState(() {
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        aiBubble.text = '네트워크 오류가 발생했어요.';
        aiBubble.isError = true;
        aiBubble.isStreaming = false;
        aiBubble.toolStatus = null;
        _isLoading = false;
      });
    } finally {
      client.close();
    }

    _scrollToBottom();
  }

  // ── 저장/불러오기 ─────────────────────────────────────
  Future<void> _loadSavedData() async {
    await _loadChecklistDataForRange();
    await _loadAllSessions();
    if (mounted) setState(() => _isDataLoaded = true);
  }

  Future<void> _loadChecklistDataForRange() async {
    final key = _rangeKey();
    final prefs = await SharedPreferences.getInstance();
    final msgJson = prefs.getString('${key}_msg');
    final histJson = prefs.getString('${key}_hist');

    if (msgJson != null) {
      final list = jsonDecode(msgJson) as List;
      _checklistMessagesCache[key] = list.map((e) => _ChatMessage(
        isAi: e['isAi'] as bool,
        text: e['text'] as String,
        isError: (e['isError'] as bool?) ?? false,
        checklistsAdded: (e['checklistsAdded'] as bool?) ?? false,
      )).toList();
    }
    if (histJson != null) {
      _checklistHistoryCache[key] = List<Map<String, dynamic>>.from(jsonDecode(histJson) as List);
    }
  }

  // ── 모든 저장된 세션 목록 로드 ───────────────────────
  Future<void> _loadAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final sessionKeys = allKeys
        .where((k) => k.startsWith(_kChecklistPrefix) && k.endsWith('_msg'))
        .toList();

    final sessions = <_SessionInfo>[];
    for (final fullKey in sessionKeys) {
      // key 형식: checklist_chat_yyyy-MM-dd_msg
      final withoutSuffix = fullKey.replaceAll('_msg', '');
      final withoutPrefix = withoutSuffix.replaceFirst(_kChecklistPrefix, '');
      // withoutPrefix: yyyy-MM-dd
      try {
        final date = DateFormat('yyyy-MM-dd').parse(withoutPrefix);
        final msgJson = prefs.getString(fullKey);
        int userMsgCount = 0;
        if (msgJson != null) {
          final list = jsonDecode(msgJson) as List;
          userMsgCount = list.where((e) => !(e['isAi'] as bool)).length;
        }
        if (userMsgCount > 0) {
          sessions.add(_SessionInfo(
            key: withoutSuffix,
            date: date,
            messageCount: userMsgCount,
          ));
        }
      } catch (_) {}
    }

    // 최신순 정렬
    sessions.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _savedSessions = sessions);
  }

  Future<void> _saveChecklistData() async {
    final key = _rangeKey();
    final prefs = await SharedPreferences.getInstance();
    final messages = _checklistMessagesCache[key] ?? [];
    final history = _checklistHistoryCache[key] ?? [];
    await prefs.setString('${key}_msg',
        jsonEncode(messages.map((m) => {
          'isAi': m.isAi, 'text': m.text,
          'isError': m.isError, 'checklistsAdded': m.checklistsAdded,
        }).toList()));
    await prefs.setString('${key}_hist', jsonEncode(history));
    await _loadAllSessions();
  }

  void _resyncHistory(
      List<_ChatMessage> messages, List<Map<String, dynamic>> history) {
    history.clear();
    bool skippedFirstAi = false;
    for (final msg in messages) {
      if (!skippedFirstAi && msg.isAi) { skippedFirstAi = true; continue; }
      if (msg.isError) continue;
      history.add({
        'role': msg.isAi ? 'model' : 'user',
        'parts': [{'text': msg.text}],
      });
    }
  }

  Future<void> _deleteMessagePair(int messageIndex) async {
    final messages = _checklistMessages();
    final history = _checklistHistory();

    if (messageIndex < 0 || messageIndex >= messages.length) return;
    if (messages[messageIndex].isAi) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 삭제'),
        content: const Text('이 대화와 AI 응답을 함께 삭제할까요?\n삭제된 내용은 AI가 참조하지 않아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      final removeCount =
      (messageIndex + 1 < messages.length && messages[messageIndex + 1].isAi)
          ? 2 : 1;
      messages.removeRange(messageIndex, messageIndex + removeCount);
      _resyncHistory(messages, history);
    });

    await _saveChecklistData();
  }

  // ── 사이드바: 세션 선택 ──────────────────────────────
  Future<void> _jumpToSession(_SessionInfo session) async {
    setState(() {
      _selectedDate = session.date;
    });
    await _loadChecklistDataForRange();
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  // ── 사이드바: 세션 삭제 ──────────────────────────────
  Future<void> _deleteSession(_SessionInfo session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대화 세션 삭제'),
        content: Text('"${session.label}" 대화를 삭제할까요?\n이 작업은 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${session.key}_msg');
    await prefs.remove('${session.key}_hist');
    _checklistMessagesCache.remove(session.key);
    _checklistHistoryCache.remove(session.key);

    await _loadAllSessions();
  }

  // ── 시스템 프롬프트 ───────────────────────────────────
  String _buildCategoryContext(List<Map<String, dynamic>> categoryList) {
    if (categoryList.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('\n[등록된 과목 목록]');
    for (final item in categoryList) {
      final category = item['category'] as SubjectCategory;
      final subjects = item['subjects'] as List<Subject>;
      if (subjects.isEmpty) continue;
      buffer.writeln('- ${category.name}: ${subjects.map((s) => s.name).join(', ')}');
    }
    return buffer.toString();
  }

  String _buildChecklistSystemPrompt(List<Map<String, dynamic>> categoryList) {
    final categoryCtx = _buildCategoryContext(categoryList);

    return '''
너는 공부 체크리스트를 정리해주는 AI 어시스턴트야.
한국어, 존댓말로 대화해줘.

[역할]
사용자가 마구잡이로 적은 할일/공부 내용을 깔끔한 체크리스트로 정리해줘.

[중요 규칙]
1. 사용자가 체크리스트 정리를 요청하면, 응답에 반드시 "체크리스트를 정리해드릴게요." 문장을 써줘.
2. 과목별로 그룹화해서 정리해줘. 과목 헤더는 **과목명** 형태로 써줘.
3. 각 항목은 "- [ ] 항목내용" 체크박스 형식으로 써줘.
4. 반드시 등록된 과목명만 사용해야 해.
5. 계획 생성이 아닌 일반 대화에는 위 마커를 쓰지 마.

예시:
체크리스트를 정리해드릴게요.

**수학**
- [ ] 미적분 교과서 3장 풀기
- [ ] 벡터 연습문제 10~15번

**영어**
- [ ] 영단어 30개 암기
- [ ] 독해 지문 2개 풀기

**물리**
- [ ] 역학 복습 노트 정리

$categoryCtx
''';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final currentMessages = _checklistMessages();
    final currentHistory = _checklistHistory();

    final categoryList = await ref.read(categoryViewModelProvider.future);
    final systemPrompt = _buildChecklistSystemPrompt(categoryList);

    // OpenRouter 키 확인
    final openRouterKey =
        await ref.read(openRouterApiKeyProvider.future);

    setState(() {
      currentMessages.add(_ChatMessage(isAi: false, text: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    currentHistory.add({'role': 'user', 'parts': [{'text': text}]});

    // 스트리밍 응답 버블 추가
    final aiBubble = _ChatMessage(isAi: true, text: '', isStreaming: true);
    setState(() => currentMessages.add(aiBubble));

    final StringBuffer buffer = StringBuffer();
    final client = http.Client();

    try {
      if (openRouterKey != null && openRouterKey.isNotEmpty) {
        // ── OpenRouter API 호출 ──
        final openRouterModel =
            ref.read(openRouterModelProvider).valueOrNull ?? defaultOpenRouterModel;
        await _sendOpenRouterRequest(
          client: client,
          apiKey: openRouterKey,
          model: openRouterModel,
          systemPrompt: systemPrompt,
          text: text,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      } else {
        // ── Hermes Agent 호출 ──
        final serverUrl = await ref.read(serverUrlProvider.future);
        final url =
            '${serverUrl.replaceAll(RegExp(r'/+$'), '')}/v1/responses';
        await _sendHermesRequest(
          client: client,
          url: url,
          systemPrompt: systemPrompt,
          text: text,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      }

      // 최종 처리
      final rawText = buffer.toString();
      if (rawText.isNotEmpty) {
        // 체크리스트 마커 감지
        const checklistMarker = '체크리스트를 정리해드릴게요.';
        final hasChecklistMarker = rawText.contains(checklistMarker);
        final checklists = hasChecklistMarker ? <_ChecklistData>[] : null;

        setState(() {
          aiBubble.text = rawText;
          aiBubble.checklists = checklists;
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });

        currentHistory.add({'role': 'model', 'parts': [{'text': rawText}]});
        await _saveChecklistData();
      } else {
        setState(() {
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        aiBubble.text = '네트워크 오류가 발생했어요.';
        aiBubble.isError = true;
        aiBubble.isStreaming = false;
        aiBubble.toolStatus = null;
        _isLoading = false;
      });
      currentHistory.removeLast();
    } finally {
      client.close();
    }

    _scrollToBottom();
  }

  /// OpenRouter API 호출
  Future<void> _sendOpenRouterRequest({
    required http.Client client,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String text,
    required _ChatMessage aiBubble,
    required StringBuffer buffer,
    required List<_ChatMessage> currentMessages,
  }) async {
    // OpenRouter용 messages 배열 구성
    final history = _checklistHistory();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    // 대화 히스토리를 OpenAI 형식으로 변환
    for (final msg in history) {
      final role = msg['role'] as String;
      final parts = msg['parts'] as List;
      final content = parts.isNotEmpty ? parts.first['text'] as String : '';
      messages.add({
        'role': role == 'model' ? 'assistant' : role,
        'content': content,
      });
    }
    messages.add({'role': 'user', 'content': text});

    final request =
        http.Request('POST', Uri.parse('https://openrouter.ai/api/v1/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
    });

    final streamedResponse = await client.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      String errorMsg;
      try {
        final err = jsonDecode(body);
        errorMsg = err['error']?['message'] ?? '알 수 없는 오류';
      } catch (_) {
        errorMsg = 'HTTP ${streamedResponse.statusCode}';
      }

      if (!mounted) return;
      setState(() {
        aiBubble.text = '오류: $errorMsg';
        aiBubble.isError = true;
        aiBubble.isStreaming = false;
        _isLoading = false;
      });
      _checklistHistory().removeLast();
      return;
    }

    // SSE 스트리밍 파싱 (OpenAI 호환)
    await streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]') return;

        try {
          final event = jsonDecode(jsonStr);
          final delta =
              event['choices']?[0]?['delta']?['content'] as String?;
          if (delta != null && delta.isNotEmpty) {
            buffer.write(delta);
            if (mounted) {
              setState(() {
                aiBubble.text = buffer.toString();
              });
            }
          }
        } catch (_) {}
      }
    });
  }

  /// Hermes Agent 호출
  Future<void> _sendHermesRequest({
    required http.Client client,
    required String url,
    required String systemPrompt,
    required String text,
    required _ChatMessage aiBubble,
    required StringBuffer buffer,
    required List<_ChatMessage> currentMessages,
  }) async {
    final convKey = 'checklist_${_rangeKey()}';

    final request = http.Request('POST', Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'input': text,
      'instructions': systemPrompt,
      'conversation': convKey,
      'stream': true,
    });

    final streamedResponse = await client.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      String errorMsg;
      try {
        final err = jsonDecode(body);
        errorMsg = err['error']?['message'] ?? '알 수 없는 오류';
      } catch (_) {
        errorMsg = 'HTTP ${streamedResponse.statusCode}';
      }

      if (streamedResponse.statusCode == 401) {
        errorMsg = '인증 실패 — 서버에서 API_SERVER_KEY를 확인해주세요';
      }

      if (!mounted) return;
      setState(() {
        aiBubble.text = '오류: $errorMsg';
        aiBubble.isError = true;
        aiBubble.isStreaming = false;
        _isLoading = false;
      });
      _checklistHistory().removeLast();
      return;
    }

    // SSE 스트리밍 파싱 (Hermes)
    await streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr == '[DONE]') return;

        try {
          final event = jsonDecode(jsonStr);
          _handleStreamEvent(event, aiBubble, buffer, currentMessages);
        } catch (_) {}
      }
    });
  }

  /// SSE 이벤트 처리
  void _handleStreamEvent(
    Map<String, dynamic> event,
    _ChatMessage bubble,
    StringBuffer buffer,
    List<_ChatMessage> messages,
  ) {
    final type = event['type'] as String?;

    switch (type) {
      case 'response.output_text.delta':
        final delta = event['delta'] as String? ?? '';
        if (delta.isNotEmpty) {
          buffer.write(delta);
          setState(() {
            bubble.text = buffer.toString();
          });
        }

      case 'response.output_text.done':
        // 최종 텍스트로 교체 (서버가 정리한 버전)
        final finalText = event['text'] as String?;
        if (finalText != null) {
          buffer.clear();
          buffer.write(finalText);
        }

      case 'hermes.tool.progress':
        final toolName = event['tool_name'] as String? ?? '';
        final status = event['status'] as String? ?? '';
        setState(() {
          bubble.toolStatus = _formatToolStatus(toolName, status);
        });

      case 'response.completed':
        // 스트리밍 완료 — 최종 처리는 _sendMessage에서

      default:
        // response.created 등 무시
    }
  }

  String _formatToolStatus(String toolName, String status) {
    final names = {
      'terminal': '명령어 실행 중',
      'write_to_file': '파일 작성 중',
      'read_file': '파일 읽는 중',
      'list_directory': '디렉토리 탐색 중',
      'search_files': '파일 검색 중',
      'web_search': '웹 검색 중',
      'crawl_webpage': '웹페이지 수집 중',
      'memory': '메모리 접근 중',
    };
    final label = names[toolName] ?? '$toolName 실행 중';
    return '$label${status.isNotEmpty ? " ($status)" : ""}...';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 초기화'),
        content: const Text('모든 대화 기록이 삭제됩니다!\n계속하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await _clearCurrentChat();
  }

  Future<void> _clearCurrentChat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final key = _rangeKey();
      _checklistMessagesCache[key] = [
        _ChatMessage(isAi: true, text: '새로운 대화를 시작합니다. 오늘 할 공부를 알려주세요.'),
      ];
      _checklistHistoryCache[key] = [];
      prefs.remove('${key}_msg');
      prefs.remove('${key}_hist');
    });
    await _loadAllSessions();
  }

  @override
  Widget build(BuildContext context) {
    final currentMessages = _checklistMessages();
    final dateDisplay = DateFormat('M월 d일 (E)', 'ko').format(_selectedDate);

    return Scaffold(
      // ── 드로어: 세션 사이드바 ────────────────────────
      drawer: _SessionDrawer(
        sessions: _savedSessions,
        currentKey: _rangeKey(),
        onSelect: (session) async {
          Navigator.pop(context);
          await _jumpToSession(session);
        },
        onDelete: (session) async {
          await _deleteSession(session);
        },
      ),
      appBar: AppBar(
        title: Text('AI 체크리스트', style: Theme.of(context).textTheme.titleMedium),
        // leading은 Drawer가 자동으로 햄버거 버튼 추가
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '대화 초기화',
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: !_isDataLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          GestureDetector(
              onHorizontalDragEnd: (details) {
                final vx = details.primaryVelocity ?? 0;
                if (vx < -200) _swipeDate(1);   // 왼쪽 스와이프 → 다음 날
                if (vx > 200) _swipeDate(-1);    // 오른쪽 스와이프 → 이전 날
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chevron_left, size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(dateDisplay,
                        style: TextStyle(fontSize: 13,
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18,
                        color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
          if (_isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.shade50,
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)),
                  const SizedBox(width: 10),
                  const Text('듣고 있어요... 말씀해주세요',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await _speech.stop();
                      setState(() => _isListening = false);
                    },
                    child: const Text('중지', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: currentMessages.length,
              itemBuilder: (context, index) {
                final message = currentMessages[index];
                return _ChatBubble(
                  message: message,
                  onDelete: message.isAi
                      ? null
                      : () => _deleteMessagePair(index),
                  onAddChecklists: (message.isAi && !message.checklistsAdded)
                      ? () => _addChecklists(index)
                      : null,
                  onRegenerate: (message.isAi && index > 0 && !_isLoading)
                      ? () => _regenerateResponse(index)
                      : null,
                  checklistsAdded: message.checklistsAdded,
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
            onMic: _toggleListening,
            isLoading: _isLoading,
            isListening: _isListening,
            speechAvailable: _speechAvailable,
            hintText: _isListening
                ? '음성을 텍스트로 변환 중...'
                : '할일을 말해보세요.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 세션 사이드바 드로어
// ══════════════════════════════════════════════════════════════

class _SessionDrawer extends StatelessWidget {
  final List<_SessionInfo> sessions;
  final String currentKey;
  final Future<void> Function(_SessionInfo) onSelect;
  final Future<void> Function(_SessionInfo) onDelete;

  const _SessionDrawer({
    required this.sessions,
    required this.currentKey,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.history,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    '대화 세션 목록',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '저장된 대화 세션이 없어요.\nAI와 체크리스트를 정리하면 여기에 표시돼요.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: sessions.length,
                  itemBuilder: (context, i) {
                    final session = sessions[i];
                    final isActive = currentKey == session.key;

                    return Dismissible(
                      key: Key(session.key),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red.shade400,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await onDelete(session);
                        return false; // _loadAllSessions가 갱신하므로 false
                      },
                      child: ListTile(
                        selected: isActive,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color: isActive
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          session.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '대화 ${session.messageCount}건',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          onPressed: () => onDelete(session),
                        ),
                        onTap: () => onSelect(session),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 채팅 말풍선 ───────────────────────────────────────────
class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;
  final VoidCallback? onDelete;   // 사용자 메시지만 전달됨
  final VoidCallback? onAddChecklists;
  final VoidCallback? onRegenerate; // AI 응답 다시 생성
  final bool checklistsAdded;

  const _ChatBubble({
    required this.message,
    this.onDelete,
    this.onAddChecklists,
    this.onRegenerate,
    this.checklistsAdded = false,
  });

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  final _bubbleKey = GlobalKey();

  Future<void> _showContextMenu() async {
    final isAi = widget.message.isAi;

    // 말풍선의 화면 위치 계산
    final renderBox =
    _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // 메뉴 표시 위치: 말풍선 위쪽 중앙
    final position = RelativeRect.fromLTRB(
      isAi ? offset.dx : offset.dx + size.width - 160,
      offset.dy - 4,
      isAi ? offset.dx + 160 : offset.dx + size.width,
      offset.dy + size.height,
    );

    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'copy',
        child: Row(
          children: const [
            Icon(Icons.copy, size: 18),
            SizedBox(width: 10),
            Text('복사'),
          ],
        ),
      ),
      if (isAi && widget.onRegenerate != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'regenerate',
          child: Row(
            children: const [
              Icon(Icons.refresh, size: 18),
              SizedBox(width: 10),
              Text('답변 다시 생성'),
            ],
          ),
        ),
      ],
      if (!isAi) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 10),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ];

    final result = await showMenu<String>(
      context: context,
      position: position,
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    );

    if (result == 'copy') {
      await _copyToClipboard(widget.message.text);
    } else if (result == 'regenerate') {
      widget.onRegenerate?.call();
    } else if (result == 'delete') {
      widget.onDelete?.call();
    }
  }

  Future<void> _copyToClipboard(String text) async {
    // flutter/services의 Clipboard 사용
    await _ClipboardHelper.copy(text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('클립보드에 복사됐어요'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAi = widget.message.isAi;
    final bubbleColor = widget.message.isError
        ? Colors.red.shade50
        : isAi
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.primary;
    final textColor = widget.message.isError
        ? Colors.red
        : isAi
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.message.isError
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                  widget.message.isError ? Icons.error : Icons.smart_toy,
                  size: 18,
                  color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onLongPress: _showContextMenu,
                  child: Container(
                    key: _bubbleKey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isAi ? 4 : 16),
                        topRight: Radius.circular(isAi ? 16 : 4),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.message.toolStatus != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: textColor),
                                ),
                                const SizedBox(width: 6),
                                Text(widget.message.toolStatus!,
                                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12)),
                              ],
                            ),
                          ),
                        if (widget.message.text.isEmpty && widget.message.isStreaming)
                          SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                          )
                        else if (isAi)
                          MarkdownBody(
                            data: widget.message.text,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: textColor, height: 1.5),
                              strong: TextStyle(color: textColor, height: 1.5, fontWeight: FontWeight.bold),
                              em: TextStyle(color: textColor, height: 1.5, fontStyle: FontStyle.italic),
                              code: TextStyle(
                                color: textColor,
                                backgroundColor: bubbleColor.withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: bubbleColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              blockquote: TextStyle(color: textColor.withValues(alpha: 0.7)),
                              h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                              h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                              h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              listBullet: TextStyle(color: textColor),
                            ),
                          )
                        else
                          Text(widget.message.text,
                              style: TextStyle(color: textColor, height: 1.5)),
                      ],
                    ),
                  ),
                ),
                if (isAi && widget.message.checklists != null && !widget.message.isStreaming) ...[
                  const SizedBox(height: 8),
                  if (widget.checklistsAdded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green.shade600),
                          const SizedBox(width: 6),
                          Text('체크리스트에 추가됐어요',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: widget.onAddChecklists,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: const Text('체크리스트에 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Clipboard 헬퍼
class _ClipboardHelper {
  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FadeTransition(opacity: _animation, child: const Text('생각 중...')),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final bool isLoading;
  final bool isListening;
  final bool speechAvailable;
  final String hintText;

  const _InputBar({
    required this.controller, required this.onSend, required this.onMic,
    required this.isLoading, required this.isListening,
    required this.speechAvailable, required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: isLoading ? null : onSend, icon: const Icon(Icons.send)),
          const SizedBox(width: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: isListening
                ? BoxDecoration(shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4),
                    blurRadius: 12, spreadRadius: 4)])
                : null,
            child: IconButton.filledTonal(
              onPressed: speechAvailable ? onMic : null,
              icon: Icon(isListening ? Icons.mic : Icons.mic_none),
              style: IconButton.styleFrom(
                foregroundColor: isListening ? Colors.white : Colors.red,
                backgroundColor: isListening ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}