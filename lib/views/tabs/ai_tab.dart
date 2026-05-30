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

}

// ── 날짜 범위 ─────────────────────────────────────────────
class _DateLabel {
  final DateTime date;
  _DateLabel({required this.date});

  String key() => '$_kPlanPrefix${DateFormat('yyyy-MM-dd').format(date)}';

  /// "5월 29일~5월 30일 새벽" 형태의 범위 라벨
  String label() {
    final next = date.add(const Duration(days: 1));
    final sameMonth = date.month == next.month;
    if (sameMonth) {
      return '${date.month}월 ${date.day}일~${next.day}일 새벽';
    }
    return '${date.month}월 ${date.day}일~${next.month}월 ${next.day}일 새벽';
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
  List<String>? pendingOptions; // 오전/오후 등 선택지 (AI 응답에서 추출)

  _ChatMessage({
    required this.isAi,
    required this.text,
    this.isError = false,
    this.plans,
    this.plansAdded = false,
    this.isStreaming = false,
    this.toolStatus,
    this.pendingOptions,
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

  String get label => _DateLabel(date: date).label();
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

  AiSession _currentSession = AiSession.dailyPlan;

  DateTime _selectedDate = DateTime.now();

  String _rangeKey() =>
      '$_kPlanPrefix${DateFormat('yyyy-MM-dd').format(_selectedDate)}';

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

  // ── 사이드바 세션 목록 ────────────────────────────────
  List<_SessionInfo> _savedSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _initSpeech();
  }

  String get _rangeLabel => _DateLabel(date: _selectedDate).label();

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
    await _loadPlanDataForRange();
    if (mounted) setState(() {});
  }

  // ── 계획 등록 버튼 처리 ───────────────────────────────
  /// AI 답변 텍스트를 직접 파싱해서 계획 추출
  List<_PlanData> _parsePlansFromText(String text) {
    final results = <_PlanData>[];
    final lines = text.split('\n');
    String? currentDate; // AI 텍스트에서 추출한 날짜 (ISO: yyyy-MM-dd)

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 날짜 패턴 감지: "5월 31일", "5월31일" 등
      final dateMatch = RegExp(r'(\d{1,2})월\s*(\d{1,2})일').firstMatch(trimmed);
      if (dateMatch != null) {
        final month = int.parse(dateMatch.group(1)!);
        final day = int.parse(dateMatch.group(2)!);
        // _selectedDate의 연도 사용
        currentDate = '${_selectedDate.year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }

      // 테이블 행: | 시간 | 활동 | 공부시간 | ...
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        // 헤더/구분선 건너뛰기
        if (cells.length < 3) continue;
        if (cells.every((c) => RegExp(r'^[-:]+$').hasMatch(c))) continue;
        if (cells[0] == '시간' || cells[0] == '과목' || cells[0] == 'Subject') continue;

        // 시간-활동-공부시간 순서
        final time = _parseTimeStr(cells[0]);
        final subject = cells[1];
        final minutes = _parseMinutesStr(cells[2]);
        if (time != null && minutes != null) {
          results.add(_PlanData(
            subjectName: subject,
            startTime: time,
            goalMinutes: minutes,
            planDate: currentDate,
          ));
        }
        continue;
      }

      // 목록 형식: "1. 09:00 - 수학, 60분" 또는 "09:00 수학 60분"
      final listMatch = RegExp(
          r'^\d+\.\s*(\d{1,2}:\d{2})\s*[-:]\s*(.+?)\s*[,]\s*(\d+)\s*분')
          .firstMatch(trimmed);
      if (listMatch != null) {
        results.add(_PlanData(
          subjectName: listMatch.group(2)!.trim(),
          startTime: listMatch.group(1)!,
          goalMinutes: int.parse(listMatch.group(3)!),
          planDate: currentDate,
        ));
        continue;
      }

      // "HH:mm 과목명 N분" 형식
      final simpleMatch = RegExp(
          r'^(\d{1,2}:\d{2})\s+(.+?)\s+(\d+)\s*분')
          .firstMatch(trimmed);
      if (simpleMatch != null) {
        results.add(_PlanData(
          subjectName: simpleMatch.group(2)!.trim(),
          startTime: simpleMatch.group(1)!,
          goalMinutes: int.parse(simpleMatch.group(3)!),
          planDate: currentDate,
        ));
      }
    }

    return results;
  }

  /// "09:00", "오전 9시", "오후 2시 30분", "5월 31일 03:00" → "09:00" 형식으로 변환
  String? _parseTimeStr(String raw) {
    final s = raw.trim();
    // 날짜+시간 형식에서 시간만 추출: "5월 31일 03:00" → "03:00"
    final withDate = RegExp(r'\d{1,2}월\s*\d{1,2}일\s+(\d{1,2}):(\d{2})').firstMatch(s);
    if (withDate != null) {
      return '${withDate.group(1)!.padLeft(2, '0')}:${withDate.group(2)}';
    }
    // HH:mm 형식
    final hhmm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (hhmm != null) {
      return '${hhmm.group(1)!.padLeft(2, '0')}:${hhmm.group(2)}';
    }
    // "오전/오후 N시 M분" 형식
    final kor = RegExp(r'(오전|오후)?\s*(\d{1,2})\s*시\s*(\d{1,2})?\s*분?').firstMatch(s);
    if (kor != null) {
      int h = int.parse(kor.group(2)!);
      int m = kor.group(3) != null ? int.parse(kor.group(3)!) : 0;
      if (kor.group(1) == '오후' && h < 12) h += 12;
      if (kor.group(1) == '오전' && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return null;
  }

  /// "60분", "1시간", "1시간 30분" → 분 단위 정수
  int? _parseMinutesStr(String raw) {
    final s = raw.trim();
    // "N분"
    final minMatch = RegExp(r'^(\d+)\s*분$').firstMatch(s);
    if (minMatch != null) return int.parse(minMatch.group(1)!);
    // "N시간 M분"
    final hmMatch = RegExp(r'(\d+)\s*시간\s*(\d+)?\s*분?').firstMatch(s);
    if (hmMatch != null) {
      int h = int.parse(hmMatch.group(1)!);
      int m = hmMatch.group(2) != null ? int.parse(hmMatch.group(2)!) : 0;
      return h * 60 + m;
    }
    // "N시간"
    final hrMatch = RegExp(r'^(\d+)\s*시간$').firstMatch(s);
    if (hrMatch != null) return int.parse(hrMatch.group(1)!) * 60;
    // 숫자만 → 분으로 간주
    if (RegExp(r'^\d+$').hasMatch(s)) return int.parse(s);
    return null;
  }

  Future<void> _addPlans(List<_PlanData> plans, int messageIndex) async {
    // plans가 비어있으면 AI 답변에서 직접 파싱
    if (plans.isEmpty) {
      final messages = _planMessages();
      if (messageIndex >= messages.length) return;

      final aiResponse = messages[messageIndex].text;
      if (aiResponse.isEmpty) return;

      plans = _parsePlansFromText(aiResponse);
      if (plans.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계획을 추출할 수 없어요. 다시 시도해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 기존 계획 삭제 (selectedDate + nextDate 범위)
    await ref.read(todayPlanViewModelProvider(_selectedDate).notifier)
        .deleteAllPlansForDate(_selectedDate);
    final nextDate = _selectedDate.add(const Duration(days: 1));
    await ref.read(todayPlanViewModelProvider(nextDate).notifier)
        .deleteAllPlansForDate(nextDate);

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

      DateTime targetDate = _selectedDate;
      if (plan.planDate != null && plan.planDate!.isNotEmpty) {
        try {
          final parts = plan.planDate!.split('-');
          targetDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } catch (_) {}
      }

      // 시간 파싱 (다양한 형식 지원)
      try {
        final timeStr = plan.startTime.trim();
        int hour = 0;
        int minute = 0;

        if (timeStr.contains(':')) {
          // "09:00" 또는 "9:30" 형식
          final parts = timeStr.split(':');
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        } else if (timeStr.contains('시')) {
          // "오전 9시" 또는 "오후 2시 30분" 형식
          final hourMatch = RegExp(r'(\d+)시').firstMatch(timeStr);
          if (hourMatch != null) {
            hour = int.parse(hourMatch.group(1)!);
          }
          final minuteMatch = RegExp(r'(\d+)분').firstMatch(timeStr);
          if (minuteMatch != null) {
            minute = int.parse(minuteMatch.group(1)!);
          }
          // 오후 처리 (12시간제 → 24시간제)
          if (timeStr.contains('오후') && hour < 12) {
            hour += 12;
          }
        }

        // 유효성 검사
        if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          targetDate = DateTime(
            targetDate.year, targetDate.month, targetDate.day,
            hour, minute,
          );
        }
      } catch (_) {}

      debugPrint('[_addPlans] targetDate=$targetDate, isUtc=${targetDate.isUtc}, '
          'hour=${targetDate.hour}, minute=${targetDate.minute}');

      // todayPlanViewModelProvider 사용 → 오늘 탭 자동 갱신
      await ref
          .read(todayPlanViewModelProvider(targetDate).notifier)
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
        messages[messageIndex].plans = plans;
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

  // ── 시간 애매함 마커 처리 ──────────────────────────────
  static bool _hasAmbiguityMarker(String text) =>
      text.contains('[TIME_AMBIGUITY:');

  static String _stripAmbiguityMarker(String text) =>
      text.replaceAll(RegExp(r'\s*\[TIME_AMBIGUITY:[^\]]*\]\s*'), '\n').trim();

  static List<String>? _extractAmbiguityOptions(String text) {
    final m = RegExp(r'\[TIME_AMBIGUITY:([^\]]*)\]').firstMatch(text);
    if (m == null) return null;
    return m.group(1)!.split('|').map((e) => e.trim()).toList();
  }

  // ── AI 응답 다시 생성 ─────────────────────────────────
  Future<void> _regenerateResponse(int aiMessageIndex) async {
    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages() : _prefMessages;
    final currentHistory = isPlan ? _planHistory() : _prefHistory;

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

    if (isPlan) await _savePlanData();
    else await _savePrefData();

    // 사용자 메시지 텍스트로 재전송 (_controller에 넣지 않고 직접 처리)
    final text = userMessage.text;
    if (text.isEmpty || _isLoading) return;

    final categoryList = isPlan
        ? await ref.read(categoryViewModelProvider.future)
        : <Map<String, dynamic>>[];
    String systemPrompt = isPlan
        ? _buildPlanSystemPrompt(categoryList)
        : _prefSystemPrompt;

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
          isPlan: isPlan,
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
          isPlan: isPlan,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      }

      final rawText = buffer.toString();
      if (rawText.isNotEmpty) {
        final hasAmbiguity = _hasAmbiguityMarker(rawText);
        final displayText = _stripAmbiguityMarker(rawText);
        final ambiguityOptions = hasAmbiguity ? _extractAmbiguityOptions(rawText) : null;

        const planMarker = '오늘자 공부 계획을 생성하겠습니다.';
        final hasPlanMarker = isPlan && rawText.contains(planMarker);
        final plans = (hasPlanMarker && !hasAmbiguity) ? <_PlanData>[] : null;

        setState(() {
          aiBubble.text = displayText;
          aiBubble.plans = plans;
          aiBubble.pendingOptions = ambiguityOptions;
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
    } finally {
      client.close();
    }

    _scrollToBottom();
  }

  // ── 오전/오후 선택 후 계획 생성 ──────────────────────
  Future<void> _sendClarification(String selectedOption) async {
    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages() : _prefMessages;
    final currentHistory = isPlan ? _planHistory() : _prefHistory;

    final categoryList = await ref.read(categoryViewModelProvider.future);
    final systemPrompt = _buildPlanSystemPrompt(categoryList);

    final openRouterKey = await ref.read(openRouterApiKeyProvider.future);

    setState(() {
      currentMessages.add(_ChatMessage(isAi: false, text: selectedOption));
      _isLoading = true;
    });
    _scrollToBottom();

    currentHistory.add({'role': 'user', 'parts': [{'text': selectedOption}]});

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
          text: selectedOption,
          isPlan: isPlan,
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
          text: selectedOption,
          isPlan: isPlan,
          aiBubble: aiBubble,
          buffer: buffer,
          currentMessages: currentMessages,
        );
      }

      final rawText = buffer.toString();
      if (rawText.isNotEmpty) {
        const planMarker = '오늘자 공부 계획을 생성하겠습니다.';
        final hasPlanMarker = isPlan && rawText.contains(planMarker);
        final plans = hasPlanMarker ? <_PlanData>[] : null;

        setState(() {
          aiBubble.text = rawText;
          aiBubble.plans = plans;
          aiBubble.isStreaming = false;
          aiBubble.toolStatus = null;
          _isLoading = false;
        });

        currentHistory.add({'role': 'model', 'parts': [{'text': rawText}]});
        if (isPlan) await _savePlanData();
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
      // key 형식: plan_chat_yyyy-MM-dd_msg
      final withoutSuffix = fullKey.replaceAll('_msg', '');
      final withoutPrefix = withoutSuffix.replaceFirst(_kPlanPrefix, '');
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
      _selectedDate = session.date;
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
    final rangeLabel = _DateLabel(date: _selectedDate).label();
    final now = DateTime.now();

    // ── 고정 prefix (캐시 최적화: 변하지 않는 부분을 맨 앞에 배치) ──
    String base = '''
너는 공부 계획을 도와주는 AI 어시스턴트야.
한국어, 존댓말로 대화해줘.

[중요 규칙]
사용자가 공부 계획 생성을 요청하면:
1. 응답 첫 줄에 반드시 "오늘자 공부 계획을 생성하겠습니다." 라는 문장을 토씨 하나 안 빼고 정확히 써줘.
2. 그 다음 줄부터 계획을 설명해줘.
3. 표 형식으로 깔끔하게 정리해줘.
4. "활동" 칸에는 반드시 등록된 과목명만 정확히 써야 해. "휴식"도 쓰지 마.

[시간 표시 규칙]
시간 칸에는 반드시 날짜를 포함해서 써줘. 예: "5월 31일 03:00"
같은 날짜가 연속되면 첫 행에만 날짜를 써도 돼.
오전인지, 오후인지, 새벽인지는 쓰지 마.

예시 응답 형식:
오늘자 공부 계획을 생성하겠습니다.
${rangeLabel} 계획을 세워드릴게요!

| 시간 | 과목 | 공부시간 |
|------|------|----------|
| 5월 30일 09:00 | 수학 | 60분 |
| 10:30 | 영어 | 45분 |
| 5월 31일 03:00 | 물리 | 60분 |

과목 칸은 반드시 등록된 과목명 그대로만 써야 해. 예를 들어 "수학"만 쓰고, "수학 집중학습"이나 "수학 복습"처럼 쓰지 마.
계획 생성이 아닌 일반 대화에는 위 문장을 쓰지 마.
''';

    // ── 동적 컨텍스트 (변동 가능성을 뒤쪽에 배치) ──
    base += '\n$categoryCtx';

    if (_prefHistory.isNotEmpty) {
      final prefSummary = _prefHistory
          .where((m) => m['role'] == 'user')
          .map((m) => (m['parts'] as List).first['text'])
          .join('\n');
      base += '\n[사용자 공부 성향 - 계획 시 반드시 반영]\n$prefSummary\n';
    }

    // ── 날짜/시간 정보 (매 요청 변동 → 가장 마지막에 배치) ──
    final nextDate = _selectedDate.add(const Duration(days: 1));
    base += '''

[현재 정보]
현재 시각: ${DateFormat('yyyy년 M월 d일 (E) HH:mm', 'ko').format(now)}
사용자가 선택한 계획 기간: ${_selectedDate.month}월 ${_selectedDate.day}일 오전 6시 ~ ${nextDate.month}월 ${nextDate.day}일 오전 6시

[시간 범위 엄수 규칙 — 반드시 지켜야 함]
사용자가 요청한 시간만 계획에 넣어줘. 위에 표시된 "계획 기간"은 가능한 시간 범위일 뿐, 그 전체를 채우지 마.
예: 사용자가 "새벽 3시~5시"를 요청하면, 5월 ${nextDate.day}일 03:00~05:00만 넣고 ${_selectedDate.day}일 저녁 시간은 절대 포함하지 마.
예: 사용자가 "15시~17시"를 요청하면, ${_selectedDate.day}일 15:00~17:00만 넣고 새벽 시간은 절대 포함하지 마.
다른 시간대를 임의로 추가하지 마.

사용자가 시간을 24시간제(예: "15시")로 표기했으면 그대로 따라줘.
시간이 오전인지 오후인지 새벽인지 애매하면(예: "3시", "9시"), 현재 시각과 상관없이 반드시 사용자에게 물어봐야 해.
선택지에는 반드시 "오전", "오후", "새벽" 세 단어만 써야 해. 시간 정보는 본문에 따로 써줘.

[TIME_AMBIGUITY:오전|오후|새벽]

예시:
사용자: "3시부터 5시 계획 짜줘" → 본문에 "오전 3시~5시 / 오후 3시~5시 / 새벽 3시~5시 중 선택해주세요"라고 쓰고, 마커는:
[TIME_AMBIGUITY:오전|오후|새벽]

사용자가 명확히 오전/오후/새벽을 표시했으면 묻지 마:
- "새벽 3시" → 새벽으로 처리
- "오후 3시" → 오후로 처리
- "오전 9시" → 오전으로 처리
- "15시부터 17시" → 오후(24시간제)로 처리

[TIME_AMBIGUITY] 표시가 포함된 응답에서는 계획 표를 만들지 마. 사용자가 선택한 후에 계획을 만들어야 해.''';

    return base;
  }

  static const String _prefSystemPrompt = '''
너는 사용자의 공부 성향을 파악하는 AI야.
사용자가 자신의 공부 습관, 취약점, 선호 시간대 등을 말하면
리스트 형태로 정리한 다음 "또 다른 성향이 있나요?" 로 끝내.
한국어 존댓말로 대화해줘.
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
        // [TIME_AMBIGUITY] 마커 감지 → 오전/오후 선택지 표시
        final hasAmbiguity = _hasAmbiguityMarker(rawText);
        final displayText = _stripAmbiguityMarker(rawText);
        final ambiguityOptions = hasAmbiguity ? _extractAmbiguityOptions(rawText) : null;

        // 계획 마커가 있으면 추출 버튼 표시를 위해 빈 plans 설정
        const planMarker = '오늘자 공부 계획을 생성하겠습니다.';
        final hasPlanMarker = isPlan && rawText.contains(planMarker);
        final plans = (hasPlanMarker && !hasAmbiguity) ? <_PlanData>[] : null;

        setState(() {
          aiBubble.text = displayText;
          aiBubble.plans = plans;
          aiBubble.pendingOptions = ambiguityOptions;
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
    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages() : _prefMessages;
    final hasPrefData = _prefHistory.isNotEmpty;
    final rangeDisplay = _DateLabel(date: _selectedDate).label();

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
                    Text(rangeDisplay,
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
                      : () => _deleteMessagePair(index, isPlan),
                  onAddPlans: (message.isAi && message.plans != null && !message.plansAdded)
                      ? () => _addPlans(message.plans!, index)
                      : null,
                  onRegenerate: (message.isAi && index > 0 && !_isLoading)
                      ? () => _regenerateResponse(index)
                      : null,
                  plansAdded: message.plansAdded,
                  onClarificationSelected: message.isAi && message.pendingOptions != null
                      ? (option) {
                          setState(() => message.pendingOptions = null);
                          _sendClarification(option);
                        }
                      : null,
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

// ── 채팅 말풍선 ───────────────────────────────────────────
class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;
  final VoidCallback? onDelete;   // 사용자 메시지만 전달됨
  final VoidCallback? onAddPlans;
  final VoidCallback? onRegenerate; // AI 응답 다시 생성
  final bool plansAdded;
  final ValueChanged<String>? onClarificationSelected;

  const _ChatBubble({
    required this.message,
    this.onDelete,
    this.onAddPlans,
    this.onRegenerate,
    this.plansAdded = false,
    this.onClarificationSelected,
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
                      label: Text(widget.message.plans!.isEmpty
                          ? '계획 추출하기'
                          : '계획 ${widget.message.plans!.length}개 추가하기'),
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
                if (widget.onClarificationSelected != null &&
                    widget.message.pendingOptions != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final option in widget.message.pendingOptions!)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onClarificationSelected!(option),
                            icon: Icon(
                              option.contains('새벽') ? Icons.nightlight_round
                                  : option.contains('오후') ? Icons.wb_sunny_outlined
                                  : Icons.wb_sunny,
                              size: 16,
                            ),
                            label: Text(option),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
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