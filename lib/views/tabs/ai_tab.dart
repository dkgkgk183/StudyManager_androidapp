import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../viewmodels/study_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../services/api_key_service.dart';
import '../../database/database.dart';
import '../../main.dart' show database;

const String _baseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent?key=';

const String _kPrefMessages = 'pref_chat_messages';
const String _kPrefHistory  = 'pref_chat_history';
const String _kPlanPrefix   = 'plan_chat_';

enum AiSession { dailyPlan, preference }

// ── 계획 데이터 모델 ──────────────────────────────────────
class _PlanData {
  final String subjectName;
  final String startTime; // "HH:mm"
  final int goalMinutes;
  final String memo;

  _PlanData({
    required this.subjectName,
    required this.startTime,
    required this.goalMinutes,
    this.memo = '',
  });

  factory _PlanData.fromJson(Map<String, dynamic> json) => _PlanData(
    subjectName: json['subjectName'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '09:00',
    goalMinutes: (json['goalMinutes'] as num?)?.toInt() ?? 60,
    memo: json['memo'] as String? ?? '',
  );
}

// ── 채팅 메시지 모델 ──────────────────────────────────────
class _ChatMessage {
  final bool isAi;
  final String text;
  final bool isError;
  final List<_PlanData>? plans; // AI가 파싱한 계획 목록
  bool plansAdded; // 이미 추가됐는지

  _ChatMessage({
    required this.isAi,
    required this.text,
    this.isError = false,
    this.plans,
    this.plansAdded = false,
  });
}

// ── JSON 파싱 유틸 ────────────────────────────────────────
// AI 응답에서 ```json ... ``` 블록 추출 및 파싱
List<_PlanData>? _extractPlans(String text) {
  final regex = RegExp(r'```json\s*([\s\S]*?)\s*```', multiLine: true);
  final match = regex.firstMatch(text);
  if (match == null) return null;

  try {
    final jsonStr = match.group(1)!;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final plans = data['plans'] as List?;
    if (plans == null || plans.isEmpty) return null;
    return plans.map((e) => _PlanData.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return null;
  }
}

// AI 응답에서 JSON 블록 제거 (사용자에게 보여줄 텍스트)
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

  String _planKey(DateTime date) =>
      '$_kPlanPrefix${DateFormat('yyyy-MM-dd').format(date)}';

  final Map<String, List<_ChatMessage>> _planMessagesCache = {};
  final Map<String, List<Map<String, dynamic>>> _planHistoryCache = {};

  List<_ChatMessage> _planMessages(DateTime date) {
    final key = _planKey(date);
    return _planMessagesCache.putIfAbsent(key, () => [
      _ChatMessage(isAi: true, text:
      '안녕하세요! 오늘의 공부 계획을 도와드릴게요 😊\n\n등록된 과목을 기반으로 계획을 짜드릴게요.\n계획을 제안하면 아래 버튼으로 한 번에 등록할 수 있어요!\n\n예시:\n"오늘 학교공부 위주로 2시간 계획 짜줘"\n"자격증 준비 일정 짜줘"'),
    ]);
  }

  List<Map<String, dynamic>> _planHistory(DateTime date) {
    final key = _planKey(date);
    return _planHistoryCache.putIfAbsent(key, () => []);
  }

  List<_ChatMessage> _prefMessages = [
    _ChatMessage(isAi: true, text:
    '여기서는 공부 성향을 자유롭게 알려주세요 📝\n\n예시:\n"나는 밤에 공부가 더 잘 돼"\n"수학은 자꾸 미루게 돼서 아침에 먼저 해야 해"\n"한 번에 1시간 이상 집중하기 힘들어"'),
  ];
  List<Map<String, dynamic>> _prefHistory = [];

  bool _isLoading = false;
  bool _isDataLoaded = false;
  DateTime _currentDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

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
                _sendMessage(_selectedDate);
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

  // ── 계획 등록 버튼 처리 ───────────────────────────────
  Future<void> _addPlansToToday(
      List<_PlanData> plans, int messageIndex, DateTime date) async {
    final allSubjects = await database.getAllSubjects();

    int addedCount = 0;
    final errors = <String>[];

    for (final plan in plans) {
      // 과목명 매칭 (대소문자 무시, 부분 매칭)
      final matched = allSubjects.where((s) =>
      s.name.contains(plan.subjectName) ||
          plan.subjectName.contains(s.name)).toList();

      if (matched.isEmpty) {
        errors.add('"${plan.subjectName}" 과목을 찾을 수 없어요');
        continue;
      }

      final subject = matched.first;

      // 시작 시간 파싱
      DateTime targetDate = date;
      try {
        final parts = plan.startTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        targetDate = DateTime(date.year, date.month, date.day, hour, minute);
      } catch (_) {}

      await ref
          .read(studyPlanViewModelProvider(date).notifier)
          .addPlan(
        subjectId: subject.id,
        targetDate: targetDate,
        goalMinutes: plan.goalMinutes,
        memo: plan.memo,
      );
      addedCount++;
    }

    // 버튼 상태 업데이트
    setState(() {
      final isPlan = _currentSession == AiSession.dailyPlan;
      final messages = isPlan ? _planMessages(date) : _prefMessages;
      if (messageIndex < messages.length) {
        messages[messageIndex].plansAdded = true;
      }
    });

    if (!mounted) return;
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedCount개의 계획이 오늘 탭에 추가됐어요 ✅'),
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

    await _loadPlanData(DateTime.now());
    if (mounted) setState(() => _isDataLoaded = true);
  }

  Future<void> _loadPlanData(DateTime date) async {
    final key = _planKey(date);
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

  Future<void> _savePrefData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefMessages,
        jsonEncode(_prefMessages.map((m) => {
          'isAi': m.isAi, 'text': m.text, 'isError': m.isError,
        }).toList()));
    await prefs.setString(_kPrefHistory, jsonEncode(_prefHistory));
  }

  Future<void> _savePlanData(DateTime date) async {
    final key = _planKey(date);
    final prefs = await SharedPreferences.getInstance();
    final messages = _planMessagesCache[key] ?? [];
    final history = _planHistoryCache[key] ?? [];
    await prefs.setString('${key}_msg',
        jsonEncode(messages.map((m) => {
          'isAi': m.isAi, 'text': m.text,
          'isError': m.isError, 'plansAdded': m.plansAdded,
        }).toList()));
    await prefs.setString('${key}_hist', jsonEncode(history));
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

  Future<void> _deleteMessagePair(
      int messageIndex, DateTime date, bool isPlan) async {
    final messages = isPlan ? _planMessages(date) : _prefMessages;
    final history = isPlan ? _planHistory(date) : _prefHistory;

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

    if (isPlan) await _savePlanData(date);
    else await _savePrefData();
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

  String _buildPlanSystemPrompt(
      List<Map<String, dynamic>> categoryList, DateTime date) {
    final categoryCtx = _buildCategoryContext(categoryList);
    String base = '''
너는 공부 계획을 도와주는 AI 어시스턴트야.
오늘 날짜는 ${DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date)}이야.
한국어로 대화해줘.
$categoryCtx

[중요 규칙]
사용자가 공부 계획 생성을 요청하면:
1. 자연스러운 한국어로 계획을 설명해줘.
2. 설명 뒤에 반드시 아래 형식의 JSON 블록을 추가해줘.
   - subjectName은 위 과목 목록의 이름을 정확히 사용해.
   - startTime은 "HH:mm" 형식 (24시간제).
   - goalMinutes는 정수(분 단위).
   - memo는 선택사항.

```json
{
  "plans": [
    {"subjectName": "수학", "startTime": "09:00", "goalMinutes": 60, "memo": "미적분"},
    {"subjectName": "영어", "startTime": "10:30", "goalMinutes": 45, "memo": ""}
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
공감하고 정리해줘. 필요하면 추가 질문도 해줘.
답변은 짧고 친근하게 해줘.
한국어로 대화해줘.
''';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _sendMessage(DateTime date) async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final apiKey = await ref.read(apiKeyProvider.future);
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정 탭에서 Gemini API 키를 먼저 입력해주세요'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages(date) : _prefMessages;
    final currentHistory = isPlan ? _planHistory(date) : _prefHistory;

    String systemPrompt = _prefSystemPrompt;
    if (isPlan) {
      final categoryList = await ref.read(categoryViewModelProvider.future);
      systemPrompt = _buildPlanSystemPrompt(categoryList, date);
    }

    setState(() {
      currentMessages.add(_ChatMessage(isAi: false, text: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    currentHistory.add({'role': 'user', 'parts': [{'text': text}]});

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {'parts': [{'text': systemPrompt}]},
          'contents': currentHistory,
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 1500},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;

        // JSON 블록에서 계획 추출
        final plans = isPlan ? _extractPlans(rawText) : null;
        // 사용자에게 보여줄 텍스트 (JSON 블록 제거)
        final displayText = _stripJsonBlock(rawText);

        // 히스토리에는 원본(JSON 포함)으로 저장
        currentHistory.add({'role': 'model', 'parts': [{'text': rawText}]});

        setState(() {
          currentMessages.add(_ChatMessage(
            isAi: true,
            text: displayText,
            plans: plans,
          ));
          _isLoading = false;
        });
        if (isPlan) await _savePlanData(date);
        else await _savePrefData();
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMsg = error['error']?['message'] ?? '알 수 없는 오류';
        setState(() {
          currentMessages.add(_ChatMessage(isAi: true, text: '오류: $errorMsg', isError: true));
          _isLoading = false;
        });
        currentHistory.removeLast();
      }
    } catch (e) {
      setState(() {
        currentMessages.add(_ChatMessage(isAi: true, text: '네트워크 오류가 발생했어요.', isError: true));
        _isLoading = false;
      });
      currentHistory.removeLast();
    }

    _scrollToBottom();
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

  Future<void> _confirmClearChat(DateTime date) async {
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
    if (confirmed == true) await _clearCurrentChat(date);
  }

  Future<void> _clearCurrentChat(DateTime date) async {
    final isPlan = _currentSession == AiSession.dailyPlan;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (isPlan) {
        final key = _planKey(date);
        _planMessagesCache[key] = [
          _ChatMessage(isAi: true, text: '새로운 대화를 시작합니다. 오늘 어떤 공부를 할 예정인가요?'),
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
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateRaw = ref.watch(selectedDateProvider);
    final selectedDate = DateTime(
        selectedDateRaw.year, selectedDateRaw.month, selectedDateRaw.day);
    _selectedDate = selectedDate;

    if (_currentDate != selectedDate) {
      _currentDate = selectedDate;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadPlanData(selectedDate);
        if (mounted) setState(() {});
      });
    }

    final isPlan = _currentSession == AiSession.dailyPlan;
    final currentMessages = isPlan ? _planMessages(selectedDate) : _prefMessages;
    final hasPrefData = _prefHistory.isNotEmpty;
    final categoryAsync = ref.watch(categoryViewModelProvider);
    final hasCategories = categoryAsync.valueOrNull
        ?.any((c) => (c['subjects'] as List).isNotEmpty) ?? false;
    final apiKeyAsync = ref.watch(apiKeyProvider);
    final hasApiKey = apiKeyAsync.valueOrNull?.isNotEmpty ?? false;
    final dateLabel = DateFormat('M월 d일 (E)', 'ko').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(isPlan ? 'AI 플래너 · $dateLabel' : 'AI 플래너'),
        actions: [
          if (isPlan && hasCategories)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: const Text('과목 연동', style: TextStyle(fontSize: 11)),
                avatar: const Icon(Icons.folder, size: 14),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ),
          if (isPlan && hasPrefData)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: const Text('성향 반영', style: TextStyle(fontSize: 11)),
                avatar: const Icon(Icons.person, size: 14),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '대화 초기화',
            onPressed: () => _confirmClearChat(selectedDate),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<AiSession>(
              segments: [
                const ButtonSegment(
                  value: AiSession.dailyPlan,
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text('일일 계획'),
                ),
                ButtonSegment(
                  value: AiSession.preference,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.person_outline, size: 16),
                      if (hasPrefData)
                        Positioned(
                          right: -4, top: -4,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  label: const Text('사용자 성향'),
                ),
              ],
              selected: {_currentSession},
              onSelectionChanged: (val) {
                setState(() => _currentSession = val.first);
                _scrollToBottom();
              },
            ),
          ),
        ),
      ),
      body: !_isDataLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (!hasApiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade100,
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('API 키가 없어요. 설정 탭에서 Gemini API 키를 입력해주세요.',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange))),
                ],
              ),
            ),
          if (!isPlan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14,
                      color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    '여기서 나눈 대화는 앱을 꺼도 저장되고, 일일 계획 세션에 자동 반영돼요',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.tertiary),
                  )),
                ],
              ),
            ),
          if (isPlan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              child: Text('📅 $dateLabel 대화',
                  style: TextStyle(fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              itemCount: currentMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == currentMessages.length) return const _TypingIndicator();
                final message = currentMessages[index];
                return _ChatBubble(
                  message: message,
                  onLongPress: message.isAi ? null
                      : () => _deleteMessagePair(index, selectedDate, isPlan),
                  onAddPlans: (message.isAi && message.plans != null && !message.plansAdded)
                      ? () => _addPlansToToday(message.plans!, index, selectedDate)
                      : null,
                  plansAdded: message.plansAdded,
                );
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: () => _sendMessage(selectedDate),
            onMic: _toggleListening,
            isLoading: _isLoading,
            isListening: _isListening,
            speechAvailable: _speechAvailable,
            hintText: _isListening
                ? '음성을 텍스트로 변환 중...'
                : isPlan
                ? '오늘 공부 계획을 말해보세요...'
                : '공부 성향을 자유롭게 말해보세요...',
          ),
        ],
      ),
    );
  }
}

// ── 채팅 말풍선 ───────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddPlans;
  final bool plansAdded;

  const _ChatBubble({
    required this.message,
    this.onLongPress,
    this.onAddPlans,
    this.plansAdded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = message.isAi;
    final bubbleColor = message.isError
        ? Colors.red.shade50
        : isAi
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.primary;
    final textColor = message.isError
        ? Colors.red
        : isAi
        ? Theme.of(context).colorScheme.onSurface
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError
                  ? Colors.red : Theme.of(context).colorScheme.primary,
              child: Icon(message.isError ? Icons.error : Icons.smart_toy,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isAi
                  ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isAi ? 4 : 16),
                        topRight: Radius.circular(isAi ? 16 : 4),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                    ),
                    child: Text(message.text,
                        style: TextStyle(color: textColor, height: 1.5)),
                  ),
                ),

                // ── 계획 등록 버튼 ─────────────────────
                if (isAi && message.plans != null) ...[
                  const SizedBox(height: 8),
                  if (plansAdded)
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
                          Text('${message.plans!.length}개 계획이 추가됐어요',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: onAddPlans,
                      icon: const Icon(Icons.add_task, size: 18),
                      label: Text('계획 ${message.plans!.length}개 오늘에 추가하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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