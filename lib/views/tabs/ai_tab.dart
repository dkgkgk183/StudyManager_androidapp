import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';

const String _apiKey = 'AIzaSyAahAEW4snCpdjhd9ek8tzyRYV1fpYGcWk';
const String _baseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$_apiKey';

enum AiSession { dailyPlan, preference }

class AiTab extends ConsumerStatefulWidget {
  const AiTab({super.key});

  @override
  ConsumerState<AiTab> createState() => _AiTabState();
}

class _AiTabState extends ConsumerState<AiTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  AiSession _currentSession = AiSession.dailyPlan;

  final List<_ChatMessage> _planMessages = [
    _ChatMessage(
      isAi: true,
      text: '안녕하세요! 오늘의 공부 계획을 도와드릴게요 😊\n\n등록된 카테고리와 과목을 참고해서 계획을 짜드릴게요.\n\n예시:\n"오늘 학교공부 위주로 2시간 계획 짜줘"\n"자격증 준비 일정 짜줘"',
    ),
  ];
  final List<Map<String, dynamic>> _planHistory = [];

  final List<_ChatMessage> _prefMessages = [
    _ChatMessage(
      isAi: true,
      text: '여기서는 공부 성향을 자유롭게 알려주세요 📝\n\n예시:\n"나는 밤에 공부가 더 잘 돼"\n"수학은 자꾸 미루게 돼서 아침에 먼저 해야 해"\n"한 번에 1시간 이상 집중하기 힘들어"',
    ),
  ];
  final List<Map<String, dynamic>> _prefHistory = [];

  bool _isLoading = false;

  // ── 카테고리/과목 → 텍스트 변환 ──────────────────────────
  String _buildCategoryContext(List<Map<String, dynamic>> categoryList) {
    if (categoryList.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n아래는 사용자가 등록한 카테고리와 과목 목록이야. 계획 제안 시 이 과목들을 활용해줘:');
    buffer.writeln('---');
    for (final item in categoryList) {
      final category = item['category'] as SubjectCategory;
      final subjects = item['subjects'] as List<Subject>;
      if (subjects.isEmpty) continue;
      final subjectNames = subjects.map((s) => s.name).join(', ');
      buffer.writeln('- ${category.name}: $subjectNames');
    }
    buffer.writeln('---');
    buffer.writeln('사용자가 카테고리 이름만 말해도 해당 과목들을 포함해서 계획을 짜줘.');
    return buffer.toString();
  }

  String _buildPlanSystemPrompt(List<Map<String, dynamic>> categoryList) {
    String base = '''
너는 공부 계획을 도와주는 AI 어시스턴트야.
사용자가 공부 계획, 시험 준비, 학습 방법에 대해 물어보면 친절하고 실용적으로 답해줘.
공부 계획을 제안할 때는 구체적인 과목, 시간, 날짜를 포함해줘.
답변은 너무 길지 않게 해줘.
한국어로 대화해줘.
''';

    // 카테고리/과목 정보 주입
    base += _buildCategoryContext(categoryList);

    // 성향 정보 주입
    if (_prefHistory.isNotEmpty) {
      final prefSummary = _prefHistory
          .where((m) => m['role'] == 'user')
          .map((m) => (m['parts'] as List).first['text'])
          .join('\n');
      base += '''

아래는 사용자가 직접 말한 공부 성향 정보야. 계획 제안 시 반드시 반영해줘:
---
$prefSummary
---
''';
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

  List<_ChatMessage> get _currentMessages =>
      _currentSession == AiSession.dailyPlan ? _planMessages : _prefMessages;

  List<Map<String, dynamic>> get _currentHistory =>
      _currentSession == AiSession.dailyPlan ? _planHistory : _prefHistory;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 일일 계획 세션이면 카테고리 데이터 먼저 로드
    String systemPrompt = _prefSystemPrompt;
    if (_currentSession == AiSession.dailyPlan) {
      final categoryList =
      await ref.read(categoryViewModelProvider.future);
      systemPrompt = _buildPlanSystemPrompt(categoryList);
    }

    setState(() {
      _currentMessages.add(_ChatMessage(isAi: false, text: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    _currentHistory.add({
      'role': 'user',
      'parts': [{'text': text}],
    });

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': systemPrompt}],
          },
          'contents': _currentHistory,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiText =
        data['candidates'][0]['content']['parts'][0]['text'] as String;
        _currentHistory.add({
          'role': 'model',
          'parts': [{'text': aiText}],
        });
        setState(() {
          _currentMessages.add(_ChatMessage(isAi: true, text: aiText));
          _isLoading = false;
        });
      } else {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMsg = error['error']?['message'] ?? '알 수 없는 오류';
        setState(() {
          _currentMessages.add(_ChatMessage(
            isAi: true,
            text: '오류가 발생했어요: $errorMsg',
            isError: true,
          ));
          _isLoading = false;
        });
        _currentHistory.removeLast();
      }
    } catch (e) {
      setState(() {
        _currentMessages.add(_ChatMessage(
          isAi: true,
          text: '네트워크 오류가 발생했어요. 인터넷 연결을 확인해주세요.',
          isError: true,
        ));
        _isLoading = false;
      });
      _currentHistory.removeLast();
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

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 초기화'),
        content: const Text('모든 대화 기록이 삭제됩니다!\n계속하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) _clearCurrentChat();
  }

  void _clearCurrentChat() {
    setState(() {
      _currentHistory.clear();
      _currentMessages.clear();
      if (_currentSession == AiSession.dailyPlan) {
        _currentMessages.add(_ChatMessage(
          isAi: true,
          text: '새로운 대화를 시작합니다. 오늘 어떤 공부를 할 예정인가요?',
        ));
      } else {
        _currentMessages.add(_ChatMessage(
          isAi: true,
          text: '성향 기록을 초기화했어요. 다시 알려주세요!',
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPrefData = _prefHistory.isNotEmpty;
    final categoryAsync = ref.watch(categoryViewModelProvider);
    final hasCategories =
        categoryAsync.valueOrNull?.any((c) => (c['subjects'] as List).isNotEmpty) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 플래너'),
        actions: [
          if (_currentSession == AiSession.dailyPlan) ...[
            if (hasCategories)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: const Text('과목 연동', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.folder, size: 14),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            if (hasPrefData)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: const Text('성향 반영', style: TextStyle(fontSize: 11)),
                  avatar: const Icon(Icons.person, size: 14),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '대화 초기화',
            onPressed: _confirmClearChat,
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
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
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
      body: Column(
        children: [
          if (_currentSession == AiSession.preference)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context)
                  .colorScheme
                  .tertiaryContainer
                  .withOpacity(0.5),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '여기서 나눈 대화는 일일 계획 세션에 자동으로 반영돼요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _currentMessages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _currentMessages.length) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(message: _currentMessages[index]);
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
            isLoading: _isLoading,
            hintText: _currentSession == AiSession.dailyPlan
                ? '오늘 공부 계획을 말해보세요...'
                : '공부 성향을 자유롭게 말해보세요...',
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isAi;
  final String text;
  final bool isError;
  _ChatMessage({required this.isAi, required this.text, this.isError = false});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

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
        mainAxisAlignment:
        isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                message.isError ? Icons.error : Icons.smart_toy,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
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
              child: Text(
                message.text,
                style: TextStyle(color: textColor, height: 1.5),
              ),
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
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            child: FadeTransition(
              opacity: _animation,
              child: const Text('생각 중...'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final String hintText;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isLoading,
    required this.hintText,
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isLoading ? null : onSend,
            icon: const Icon(Icons.send),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            onPressed: () {
              // TODO: 음성인식 구현 예정
            },
            icon: const Icon(Icons.mic),
            style: IconButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}