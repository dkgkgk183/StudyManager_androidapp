import 'dart:async';
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

const String _kPrefMessages = 'pref_chat_messages';
const String _kPrefHistory  = 'pref_chat_history';
const String _kPlanPrefix   = 'plan_chat_';

enum AiSession { dailyPlan, preference }

// ── 계획 데이터 모델 ──────────────────────────────────────
class _PlanData {
  final String subjectName;
  final String startTime;
  final int goalMinutes;
  final String memo;
  final String? planDate;

  _PlanData({
    required this.subjectName,
    required this.startTime,
    required this.goalMinutes,
    this.memo = '',
    this.planDate,
  });

  factory _PlanData.fromJson(Map<String, dynamic> json) => _PlanData(
    subjectName: json['subjectName'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '09:00',
    goalMinutes: (json['goalMinutes'] as num?)?.toInt() ?? 60,
    memo: json['memo'] as String? ?? '',
    planDate: json['date'] as String?,
  );
}

// ── 날짜 범위 ─────────────────────────────────────────────
class _DateRange {
  final DateTime start;
  final DateTime end;
  _DateRange({required this.start, required this.end});

  String key() => '$_kPlanPrefix${DateFormat('yyyy-MM-dd').format(start)}_${DateFormat('yyyy-MM-dd').format(end)}';

  String label() {
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return DateFormat('M월 d일 (E)', 'ko').format(start);
    }
    final s = DateFormat('M월 d일', 'ko').format(start);
    final e = DateFormat('M월 d일 (E)', 'ko').format(end);
    return '$s ~ $e';
  }
}

// ── 채팅 메시지 모델 ──────────────────────────────────────
class _ChatMessage {
  final bool isAi;
  String text;
  bool isError;
  List<_PlanData>? plans;
  bool plansAdded;
  bool isStreaming;
  String? toolStatus;

  _ChatMessage({
    required this.isAi,
    required this.text,
    this.isError = false,
    this.plans,
    this.plansAdded = false,
    this.isStreaming = false,
    this.toolStatus,
  });
}

// ── 저장된 세션 정보 ──────────────────────────────────────
class _SessionInfo {
  final String key;       // SharedPreferences 키
  final DateTime start;
  final DateTime end;
  final int messageCount; // 사용자 메시지 수

  _SessionInfo({
    required this.key,
    required this.start,
    required this.end,
    required this.messageCount,
  });

  String get label => _DateRange(start: start, end: end).label();
}

// ── JSON 파싱 유틸 ────────────────────────────────────────
List<_PlanData>? _extractPlans(String text) {
  // ① 완전한 ```json ... ``` 블록 우선 시도
  final closedRegex = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true);
  final closedMatch = closedRegex.firstMatch(text);

  String? jsonStr;
  if (closedMatch != null) {
    jsonStr = closedMatch.group(1)!;
  } else {
    // ② 닫는 ``` 없이 잘린 경우: ```json 이후 끝까지
    final openRegex = RegExp(r'```json\s*([\s\S]*)', multiLine: true);
    final openMatch = openRegex.firstMatch(text);
    if (openMatch != null) {
      jsonStr = openMatch.group(1)!.trim();
    }
  }

  if (jsonStr == null || jsonStr.isEmpty) return null;

  // ③ 완전한 JSON 파싱 시도
  try {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final plans = data['plans'] as List?;
    if (plans == null || plans.isEmpty) return null;
    return _parsePlanList(plans);
  } catch (_) {}

  // ④ JSON이 잘렸을 때: 완성된 객체만 추출
  return _extractPartialPlans(jsonStr);
}

List<_PlanData>? _extractPartialPlans(String jsonStr) {
  final plansStart = jsonStr.indexOf('"plans"');
  if (plansStart == -1) return null;

  final bracketStart = jsonStr.indexOf('[', plansStart);
  if (bracketStart == -1) return null;

  final results = <_PlanData>[];
  int depth = 0;
  int objStart = -1;

  for (int i = bracketStart; i < jsonStr.length; i++) {
    final ch = jsonStr[i];
    if (ch == '{') {
      if (depth == 0) objStart = i;
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0 && objStart != -1) {
        final objStr = jsonStr.substring(objStart, i + 1);
        try {
          final obj = jsonDecode(objStr) as Map<String, dynamic>;
          results.add(_PlanData.fromJson(obj));
        } catch (_) {}
        objStart = -1;
      }
    }
  }

  return results.isNotEmpty ? results : null;
}

List<_PlanData> _parsePlanList(List plans) {
  return plans
      .whereType<Map<String, dynamic>>()
      .map((e) => _PlanData.fromJson(e))
      .toList();
}

String _stripJsonBlock(String text) =>
    text.replaceAll(RegExp(r'```json\s*[\s\S]*?```', multiLine: true), '').trim();

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

  AiSession _currentSession = AiSession.dailyPlan;

  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  String _rangeKey() =>
      '$_kPlanPrefix${DateFormat('yyyy-MM-dd').format(_rangeStart)}_${DateFormat('yyyy-MM-dd').format(_rangeEnd)}';

  final Map<String, List<_ChatMessage>> _planMessagesCache = {};
  final Map<String, List<Map<String, dynamic>>> _planHistoryCache = {};

  List<_ChatMessage> _planMessages() {
    final key = _rangeKey();
    return _planMessagesCache.putIfAbsent(key, () => [
      _ChatMessage(isAi: true, text:
      '안녕하세요! 공부 계획을 도와드릴게요 😊\n\n날짜를 선택하면 해당 기간의 계획을 세울 수 있어요.\n등록된 과목을 기반으로 계획을 제안해드리고, 버튼으로 한 번에 등록할 수 있어요!\n\n예시:\n"${_rangeLabel} 기간으로 수학 위주 계획 짜줘"\n"오늘 자격증 준비 일정 짜줘"'),
    ]);
  }

  List<Map<String, dynamic>> _planHistory() {
    final key = _rangeKey();
    return _planHistoryCache.putIfAbsent(key, () => []);
  }

  List<_ChatMessage> _prefMessages = [
    _ChatMessage(isAi: true, text:
    '여기서는 공부 성향을 자유롭게 알려주세요 📝\n\n예시:\n"나는 밤에 공부가 더 잘 돼"\n"수학은 자꾸 미루게 돼서 아침에 먼저 해야 해"\n"한 번에 1시간 이상 집중하기 힘들어"'),
  ];
  List<Map<String, dynamic>> _prefHistory = [];

  bool _isLoading = false;
  bool _isDataLoaded = false;
  DateTime _prevSelectedDate = DateTime.now();

  // ── 사이드바 세션 목록 ────────────────────────────────
  List<_SessionInfo> _savedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _initSpeech();
  }

  String get _rangeLabel => _DateRange(start: _rangeStart, end: _rangeEnd).label();

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

  // ── 기간 선택 다이얼로그 ──────────────────────────────
  Future<void> _pickDateRange() async {
    final picked = await showDialog<_DateRange>(
      context: context,
      builder: (context) => _DateRangePickerDialog(
        start: _rangeStart,
        end: _rangeEnd,
      ),
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
      await _loadPlanDataForRange();
    }
  }

  // ── 계획 등록 버튼 처리 ───────────────────────────────
  Future<void> _addPlans(List<_PlanData> plans, int messageIndex) async {
    final allSubjects = await database.getAllSubjects();

    int addedCount = 0;
    final errors = <String>[];

    for (final plan in plans) {
      final matched = allSubjects.where((s) =>
      s.name.contains(plan.subjectName) ||
          plan.subjectName.contains(s.name)).toList();

      if (matched.isEmpty) {
        errors.add('"${plan.subjectName}" 과목을 찾을 수 없어요');
        continue;
      }

      final subject = matched.first;

      DateTime targetDate = _rangeStart;
      if (plan.planDate != null) {
        try {
          final parsed = DateFormat('yyyy-MM-dd').parse(plan.planDate!);
          targetDate = DateTime(parsed.year, parsed.month, parsed.day);
        } catch (_) {}
      }

      try {
        final parts = plan.startTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        targetDate = DateTime(
          targetDate.year, targetDate.month, targetDate.day,
          hour, minute,
        );
      } catch (_) {}

      await ref
          .read(studyPlanViewModelProvider(targetDate).notifier)
          .addPlan(
        subjectId: subject.id,
        targetDate: targetDate,
        goalMinutes: plan.goalMinutes,
        memo: plan.memo,
      );
      addedCount++;
    }

    setState(() {
      final messages = _planMessages();
      if (messageIndex < messages.length) {
        messages[messageIndex].plansAdded = true;
      }
    });

    if (!mounted) return;
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount개의 계획이 추가됐어요 ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount개 추가, ${errors.join(' / ')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ── 저장/불러오기 ─────────────────────────────────────
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final prefMsgJson = prefs.getString(_kPrefMessages);
    final prefHistJson = prefs.getString(_kPrefHistory);

    if (prefMsgJson != null) {
      final list = jsonDecode(prefMsgJson) as List;
      _prefMessages = list.map((e) => _ChatMessage(
        isAi: e['isAi'] as bool,
        text: e['text'] as String,
        isError: (e['isError'] as bool?) ?? false,
      )).toList();
    }
    if (prefHistJson != null) {
      _prefHistory = List<Map<String, dynamic>>.from(jsonDecode(prefHistJson) as List);
    }

    await _loadPlanDataForRange();
    await _loadAllSessions();
    if (mounted) setState(() => _isDataLoaded = true);
  }

  Future<void> _loadPlanDataForRange() async {
    final key = _rangeKey();
    final prefs = await SharedPreferences.getInstance();
    final msgJson = prefs.getString('${key}_msg');
    final histJson = prefs.getString('${key}_hist');

    if (msgJson != null) {
      final list = jsonDecode(msgJson) as List;
      _planMessagesCache[key] = list.map((e) => _ChatMessage(
        isAi: e['isAi'] as bool,
        text: e['text'] as String,
        isError: (e['isError'] as bool?) ?? false,
        plansAdded: (e['plansAdded'] as bool?) ?? false,
      )).toList();
    }
    if (histJson != null) {
      _planHistoryCache[key] = List<Map<String, dynamic>>.from(jsonDecode(histJson) as List);
    }
  }

  // ── 모든 저장된 세션 목록 로드 ───────────────────────
  Future<void> _loadAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final sessionKeys = allKeys
        .where((k) => k.startsWith(_kPlanPrefix) && k.endsWith('_msg'))
        .toList();

    final sessions = <_SessionInfo>[];
    for (final fullKey in sessionKeys) {
      // key 형식: plan_chat_yyyy-MM-dd_yyyy-MM-dd_msg
      final withoutSuffix = fullKey.replaceAll('_msg', '');
      final withoutPrefix = withoutSuffix.replaceFirst(_kPlanPrefix, '');
      // withoutPrefix: yyyy-MM-dd_yyyy-MM-dd
      final parts = withoutPrefix.split('_');
      if (parts.length < 2) continue;
      try {
        final start = DateFormat('yyyy-MM-dd').parse(parts[0]);
        final end = DateFormat('yyyy-MM-dd').parse(parts[1]);
        final msgJson = prefs.getString(fullKey);
        int userMsgCount = 0;
        if (msgJson != null) {
          final list = jsonDecode(msgJson) as List;
          userMsgCount = list.where((e) => !(e['isAi'] as bool)).length;
        }
        if (userMsgCount > 0) {
          sessions.add(_SessionInfo(
            key: withoutSuffix,
            start: start,
            end: end,
            messageCount: userMsgCount,
          ));
        }
      } catch (_) {}
    }

    // 최신순 정렬
    sessions.sort((a, b) => b.start.compareTo(a.start));
    if (mounted) setState(() => _savedSessions = sessions);
  }

  Future<void> _savePrefData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefMessages,
        jsonEncode(_prefMessages.map((m) => {
          'isAi': m.isAi, 'text': m.text, 'isError': m.isError,
        }).toList()));
    await prefs.setString(_kPrefHistory, jsonEncode(_prefHistory));
  }

  Future<void> _savePlanData() async {
    final key = _rangeKey();
    final prefs = await SharedPreferences.getInstance();
    final messages = _planMessagesCache[key] ?? [];
    final history = _planHistoryCache[key] ?? [];
    await prefs.setString('${key}_msg',
        jsonEncode(messages.map((m) => {
          'isAi': m.isAi, 'text': m.text,
          'isError': m.isError, 'plansAdded': m.plansAdded,
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

  Future<void> _deleteMessagePair(int messageIndex, bool isPlan) async {
    final messages = isPlan ? _planMessages() : _prefMessages;
    final history = isPlan ? _planHistory() : _prefHistory;

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

    if (isPlan) await _savePlanData();
    else await _savePrefData();
  }

  // ── 사이드바: 세션 선택 ──────────────────────────────
  Future<void> _jumpToSession(_SessionInfo session) async {
    setState(() {
      _rangeStart = session.start;
      _rangeEnd = session.end;
      _currentSession = AiSession.dailyPlan;
    });
    await _loadPlanDataForRange();
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
    _planMessagesCache.remove(session.key);
    _planHistoryCache.remove(session.key);

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

  String _buildPlanSystemPrompt(List<Map<String, dynamic>> categoryList) {
    final categoryCtx = _buildCategoryContext(categoryList);
    final rangeLabel = _DateRange(start: _rangeStart, end: _rangeEnd).label();
    String base = '''
너는 공부 계획을 도와주는 AI 어시스턴트야.
오늘 날짜는 ${DateFormat('yyyy년 M월 d일 (E)', 'ko').format(DateTime.now())}이야.
계획 기간: $rangeLabel이야.
한국어로 대화해줘.
$categoryCtx

[날짜 기준]
이 앱에서는 오전 6시를 기준으로 하루가 시작돼.
- "5월 29일"은 5월 29일 06:00 ~ 5월 30일 05:59까지야.
- 새벽 시간(00:00~05:59)에 공부할 계획이 있으면 전날 날짜로 지정해줘.
  예: 새벽 2시에 공부할 계획 → date는 전날 날짜

[중요 규칙]
사용자가 공부 계획 생성을 요청하면:
1. 자연스러운 한국어 존댓말로 계획을 설명해줘.
2. 설명 뒤에 반드시 아래 형식의 JSON 블록을 추가해줘.
   - date는 "yyyy-MM-dd" 형식으로 기간 내의 날짜를 지정해줘.
   - subjectName은 위 과목 목록의 이름을 정확히 사용해.
   - startTime은 "HH:mm" 형식 (24시간제).
   - goalMinutes는 정수(분 단위).
   - memo는 선택사항.

```json
{
  "plans": [
    {"date": "${DateFormat('yyyy-MM-dd').format(_rangeStart)}", "subjectName": "수학", "startTime": "09:00", "goalMinutes": 60, "memo": "미적분"},
    {"date": "${DateFormat('yyyy-MM-dd').format(_rangeStart)}", "subjectName": "영어", "startTime": "10:30", "goalMinutes": 45, "memo": ""}
  ]
}
```

계획 생성이 아닌 일반 대화에는 JSON 블록을 추가하지 마.
답변은 너무 길지 않게 해줘.
''';

    if (_prefHistory.isNotEmpty) {
      final prefSummary = _prefHistory
          .where((m) => m['role'] == 'user')
          .map((m) => (m['parts'] as List).first['text'])
          .join('\n');
      base += '\n[사용자 공부 성향 - 계획 시 반드시 반영]\n$prefSummary\n';
    }
    return base;
  }

  static const String _prefSystemPrompt = '''
너는 사용자의 공부 성향을 파악하는 AI야.
사용자가 자신의 공부 습관, 취약점, 선호 시간대 등을 말하면
리스트 형태로 정리한 다음 "또 다른 성향이 있나요?" 로 끝내.
한국어 존댓말로 대화해줘.

사용자가 성향을 말할 때마다 반드시 memory 도구를 사용해서 저장해.
저장할 때는 제목을 "사용자 학습 성향"으로 하고, 새로운 성향이 나올 때마다 기존 내용에 추가해.
''';

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

    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages() : _prefMessages;
    final currentHistory = isPlan ? _planHistory() : _prefHistory;

    String systemPrompt = _prefSystemPrompt;
    if (isPlan) {
      final categoryList = await ref.read(categoryViewModelProvider.future);
      systemPrompt = _buildPlanSystemPrompt(categoryList);
    }

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
          isPlan: isPlan,
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
          isPlan: isPlan,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      }

      // 최종 처리
      final rawText = buffer.toString();
      if (rawText.isNotEmpty) {
        final plans = isPlan ? _extractPlans(rawText) : null;
        final displayText = _stripJsonBlock(rawText);

        setState(() {
          aiBubble.text = displayText;
          aiBubble.plans = plans;
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });

        currentHistory.add({'role': 'model', 'parts': [{'text': rawText}]});
        if (isPlan) await _savePlanData();
        else await _savePrefData();
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
    required bool isPlan,
    required _ChatMessage aiBubble,
    required StringBuffer buffer,
    required List<_ChatMessage> currentMessages,
  }) async {
    // OpenRouter용 messages 배열 구성
    final history = isPlan ? _planHistory() : _prefHistory;
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
      final history = isPlan ? _planHistory() : _prefHistory;
      history.removeLast();
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
    required bool isPlan,
    required _ChatMessage aiBubble,
    required StringBuffer buffer,
    required List<_ChatMessage> currentMessages,
  }) async {
    final convKey = isPlan ? 'plan_${_rangeKey()}' : 'pref';

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
      final history = isPlan ? _planHistory() : _prefHistory;
      history.removeLast();
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
    final isPlan = _currentSession == AiSession.dailyPlan;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isPlan) {
        final key = _rangeKey();
        _planMessagesCache[key] = [
          _ChatMessage(isAi: true, text: '새로운 대화를 시작합니다. 어떤 공부를 할 예정인가요?'),
        ];
        _planHistoryCache[key] = [];
        prefs.remove('${key}_msg');
        prefs.remove('${key}_hist');
      } else {
        _prefMessages = [
          _ChatMessage(isAi: true, text: '성향 기록을 초기화했어요. 다시 알려주세요!'),
        ];
        _prefHistory = [];
        prefs.remove(_kPrefMessages);
        prefs.remove(_kPrefHistory);
      }
    });
    await _loadAllSessions();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateRaw = ref.watch(selectedDateProvider);
    final selectedDate = DateTime(
        selectedDateRaw.year, selectedDateRaw.month, selectedDateRaw.day);

    if (_prevSelectedDate != selectedDate) {
      _prevSelectedDate = selectedDate;
      setState(() {
        _rangeStart = selectedDate;
        _rangeEnd = selectedDate;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadPlanDataForRange();
        if (mounted) setState(() {});
      });
    }

    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages() : _prefMessages;
    final hasPrefData = _prefHistory.isNotEmpty;
    final rangeDisplay = _DateRange(start: _rangeStart, end: _rangeEnd).label();

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
        title: SegmentedButton<AiSession>(
          segments: [
            const ButtonSegment(
              value: AiSession.dailyPlan,
              icon: Icon(Icons.calendar_today, size: 14),
              label: Text('계획', style: TextStyle(fontSize: 12)),
            ),
            ButtonSegment(
              value: AiSession.preference,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.person_outline, size: 14),
                  if (hasPrefData)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              label: const Text('성향', style: TextStyle(fontSize: 12)),
            ),
          ],
          selected: {_currentSession},
          onSelectionChanged: (val) {
            setState(() => _currentSession = val.first);
            _scrollToBottom();
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
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
          if (isPlan)
            InkWell(
              onTap: _pickDateRange,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(rangeDisplay,
                        style: TextStyle(fontSize: 13,
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_calendar, size: 14,
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
                      : () => _deleteMessagePair(index, isPlan),
                  onAddPlans: (message.isAi && message.plans != null && !message.plansAdded)
                      ? () => _addPlans(message.plans!, index)
                      : null,
                  plansAdded: message.plansAdded,
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
                : isPlan
                ? '계획을 말해보세요.'
                : '공부 성향을 말해보세요.',
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
                  '저장된 대화 세션이 없어요.\nAI와 계획을 세우면 여기에 표시돼요.',
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
                    final isCurrent = session.key == currentKey.replaceAll(_kPlanPrefix, _kPlanPrefix);
                    // currentKey 비교
                    final isActive = currentKey == session.key ||
                        currentKey.replaceAll(_kPlanPrefix, '') == session.key.replaceAll(_kPlanPrefix, '');

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

// ── 날짜 범위 선택 다이얼로그 ─────────────────────────────────
class _DateRangePickerDialog extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  const _DateRangePickerDialog({required this.start, required this.end});

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end;
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _end = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sLabel = DateFormat('yyyy년 M월 d일', 'ko').format(_start);
    final eLabel = DateFormat('yyyy년 M월 d일', 'ko').format(_end);
    return AlertDialog(
      title: const Text('계획 기간 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _pickStart,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('시작일', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(sLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickEnd,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('종료일', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(eLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _DateRange(start: _start, end: _end)),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

// ── 채팅 말풍선 ───────────────────────────────────────────
class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;
  final VoidCallback? onDelete;   // 사용자 메시지만 전달됨
  final VoidCallback? onAddPlans;
  final bool plansAdded;

  const _ChatBubble({
    required this.message,
    this.onDelete,
    this.onAddPlans,
    this.plansAdded = false,
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
      // 클립보드 복사
      await _copyToClipboard(widget.message.text);
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
                if (isAi && widget.message.plans != null && !widget.message.isStreaming) ...[
                  const SizedBox(height: 8),
                  if (widget.plansAdded)
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
                          Text('${widget.message.plans!.length}개 계획이 추가됐어요',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: widget.onAddPlans,
                      icon: const Icon(Icons.add_task, size: 18),
                      label:
                      Text('계획 ${widget.message.plans!.length}개 추가하기'),
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