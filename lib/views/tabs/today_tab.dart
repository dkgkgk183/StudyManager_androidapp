import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';
import '../study_lock_screen.dart';

class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key});

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _getMonday(DateTime.now());
  }

  DateTime _getMonday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  void _prevWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));

  void _nextWeek() =>
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  void _selectDate(DateTime date) {
    ref.read(selectedDateProvider.notifier).setDate(date);
    final monday = _getMonday(date);
    if (monday != _weekStart) setState(() => _weekStart = monday);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final plansAsync = ref.watch(studyPlanViewModelProvider(selectedDate));
    final sessionsAsync = ref.watch(studySessionViewModelProvider(selectedDate));
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final days = _weekDays;

    final firstMonth = DateFormat('yyyy년 M월', 'ko').format(days.first);
    final lastMonth = DateFormat('yyyy년 M월', 'ko').format(days.last);
    final monthLabel = firstMonth == lastMonth
        ? firstMonth
        : '$firstMonth - ${DateFormat('M월', 'ko').format(days.last)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 M월 d일 (E)', 'ko').format(selectedDate),
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // ── 주간 날짜 바 ──────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _prevWeek,
                        icon: const Icon(Icons.chevron_left),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(monthLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      IconButton(
                        onPressed: _nextWeek,
                        icon: const Icon(Icons.chevron_right),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: days.map((date) {
                      final isSelected = date == selectedDate;
                      final isToday = date == today;
                      final isSat = date.weekday == DateTime.saturday;
                      final isSun = date.weekday == DateTime.sunday;

                      Color dayNumColor;
                      if (isSelected) {
                        dayNumColor = Colors.white;
                      } else if (isToday) {
                        dayNumColor = Theme.of(context).colorScheme.primary;
                      } else if (isSat) {
                        dayNumColor = Colors.blue;
                      } else if (isSun) {
                        dayNumColor = Colors.red;
                      } else {
                        dayNumColor =
                            Theme.of(context).colorScheme.onSurface;
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(date),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : isToday
                                  ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  DateFormat('E', 'ko').format(date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.85)
                                        : isSat
                                        ? Colors.blue
                                        : isSun
                                        ? Colors.red
                                        : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date.day.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: dayNumColor,
                                  ),
                                ),
                                SizedBox(
                                  height: 5,
                                  child: isToday
                                      ? Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? Colors.white
                                            : Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── 콘텐츠 ───────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(
                  title: '오늘의 계획',
                  onAdd: () =>
                      _showAddPlanDialog(context, ref, selectedDate),
                ),
                const SizedBox(height: 8),
                plansAsync.when(
                  data: (plans) {
                    if (plans.isEmpty) {
                      return const _EmptyHint(
                          message: 'AI 탭에서 계획을 만들거나\n직접 추가해보세요');
                    }
                    return Column(
                      children: plans.map((item) {
                        final plan = item['plan'] as StudyPlan;
                        final subject = item['subject'] as Subject;
                        return _PlanCard(
                            plan: plan,
                            subject: subject,
                            date: selectedDate);
                      }).toList(),
                    );
                  },
                  loading: () =>
                  const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('오류: $e'),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: '오늘의 공부 기록'),
                const SizedBox(height: 8),
                sessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return const _EmptyHint(message: '아직 공부 기록이 없어요');
                    }
                    return Column(
                      children: sessions.map((item) {
                        final session = item['session'] as StudySession;
                        final subject = item['subject'] as Subject;
                        return _SessionCard(
                            session: session,
                            subject: subject,
                            date: selectedDate);
                      }).toList(),
                    );
                  },
                  loading: () =>
                  const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('오류: $e'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showStartSessionDialog(context, ref, selectedDate),
        icon: const Icon(Icons.play_arrow),
        label: const Text('공부 시작'),
      ),
    );
  }

  // ── 계획 추가 ─────────────────────────────────────────
  Future<void> _showAddPlanDialog(
      BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final categoryList = await ref.read(categoryViewModelProvider.future);
    final validCategories = categoryList
        .where((c) => (c['subjects'] as List<Subject>).isNotEmpty)
        .toList();

    if (!context.mounted) return;

    if (validCategories.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('과목이 없어요'),
          content: const Text('설정 탭에서 카테고리와 과목을 먼저 추가해주세요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인')),
          ],
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _AddPlanDialog(
        selectedDate: selectedDate,
        validCategories: validCategories,
        onAdd: ({
          required String subjectId,
          required DateTime targetDate,
          required int goalMinutes,
          required String memo,
        }) async {
          await ref
              .read(studyPlanViewModelProvider(selectedDate).notifier)
              .addPlan(
            subjectId: subjectId,
            targetDate: targetDate,
            goalMinutes: goalMinutes,
            memo: memo,
          );
        },
      ),
    );
  }

  // ── 공부 시작 ─────────────────────────────────────────
  Future<void> _showStartSessionDialog(
      BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final subjects = await ref.read(subjectViewModelProvider.future);
    if (!context.mounted) return;

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 설정에서 과목을 추가해주세요')),
      );
      return;
    }

    String selectedSubjectId = subjects.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('공부 시작'),
          content: DropdownButtonFormField<String>(
            value: selectedSubjectId,
            decoration:
            const InputDecoration(labelText: '과목', isDense: true),
            items: subjects
                .map((s) =>
                DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => selectedSubjectId = v!),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('시작')),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final id = await ref
        .read(studySessionViewModelProvider(selectedDate).notifier)
        .startSession(subjectId: selectedSubjectId);
    ref.read(activeSessionIdProvider.notifier).setSession(id);

    final subject =
    subjects.firstWhere((s) => s.id == selectedSubjectId);

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            StudyLockScreen(sessionId: id, subject: subject),
        fullscreenDialog: true,
      ),
    );
  }
}

// ── 계획 추가 다이얼로그 ──────────────────────────────────
class _AddPlanDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> validCategories;
  final Future<void> Function({
  required String subjectId,
  required DateTime targetDate,
  required int goalMinutes,
  required String memo,
  }) onAdd;

  const _AddPlanDialog({
    required this.selectedDate,
    required this.validCategories,
    required this.onAdd,
  });

  @override
  State<_AddPlanDialog> createState() => _AddPlanDialogState();
}

class _AddPlanDialogState extends State<_AddPlanDialog> {
  late Map<String, dynamic> _selectedCategory;
  late Subject _selectedSubject;
  TimeOfDay? _selectedTime;
  final _goalCtrl = TextEditingController(text: '60');
  final _memoCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.validCategories.first;
    _selectedSubject =
        (_selectedCategory['subjects'] as List<Subject>).first;
    // 목표 시간 변경 시 종료 시각 자동 업데이트
    _goalCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  List<Subject> get _currentSubjects =>
      _selectedCategory['subjects'] as List<Subject>;

  // 종료 시각 계산
  String? get _endTimeString {
    if (_selectedTime == null) return null;
    final goalMinutes = int.tryParse(_goalCtrl.text) ?? 0;
    if (goalMinutes <= 0) return null;
    final totalMinutes =
        _selectedTime!.hour * 60 + _selectedTime!.minute + goalMinutes;
    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;
    final endTime = TimeOfDay(hour: endHour, minute: endMinute);
    return endTime.format(context);
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final isToday = widget.selectedDate ==
        DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day);

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
    );
    if (picked == null) return;

    if (isToday) {
      final nowMinutes = now.hour * 60 + now.minute;
      final pickedMinutes = picked.hour * 60 + picked.minute;
      if (pickedMinutes < nowMinutes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('현재 시간 이전은 설정할 수 없어요')),
          );
        }
        return;
      }
    }
    setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _endTimeString;

    return AlertDialog(
      title: const Text('계획 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리
            const Text('카테고리',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: widget.validCategories.map((c) {
                final cat = c['category'] as SubjectCategory;
                return DropdownMenuItem(value: c, child: Text(cat.name));
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedCategory = v;
                  _selectedSubject =
                      (_selectedCategory['subjects'] as List<Subject>)
                          .first;
                });
              },
            ),
            const SizedBox(height: 12),

            // 과목
            const Text('과목',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButtonFormField<Subject>(
              value: _selectedSubject,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: _currentSubjects.map((s) {
                final color = _colorFromHex(s.colorHex);
                return DropdownMenuItem(
                  value: s,
                  child: Row(children: [
                    CircleAvatar(backgroundColor: color, radius: 6),
                    const SizedBox(width: 8),
                    Text(s.name),
                  ]),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSubject = v);
              },
            ),
            const SizedBox(height: 12),

            // 시작 시간 (필수)
            Row(
              children: [
                const Text('시작 시간',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 4),
                Text('*',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error)),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedTime != null
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        color: _selectedTime != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      _selectedTime != null
                          ? _selectedTime!.format(context)
                          : '시작 시간을 선택해주세요',
                      style: TextStyle(
                          color: _selectedTime != null
                              ? null
                              : Colors.grey),
                    ),
                    const Spacer(),
                    if (_selectedTime != null)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedTime = null),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 목표 공부 시간
            const Text('목표 공부 시간',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: _goalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                suffixText: '분',
              ),
            ),

            // 종료 시각 자동 표시
            if (endTime != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '종료 예정: $endTime',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // 메모
            const Text('메모',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '선택 사항',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          // 시작 시간 미선택 시 비활성화
          onPressed: (_isLoading || _selectedTime == null)
              ? null
              : () async {
            setState(() => _isLoading = true);
            final targetDate = DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            );
            await widget.onAdd(
              subjectId: _selectedSubject.id,
              targetDate: targetDate,
              goalMinutes: int.tryParse(_goalCtrl.text) ?? 60,
              memo: _memoCtrl.text,
            );
            if (mounted) Navigator.pop(context);
          },
          child: _isLoading
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('추가'),
        ),
      ],
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const _SectionHeader({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const Spacer(),
        if (onAdd != null)
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('추가'),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

// ── 계획 카드 (체크박스 없음, 길게 누르면 삭제) ─────────────
class _PlanCard extends ConsumerStatefulWidget {
  final StudyPlan plan;
  final Subject subject;
  final DateTime date;
  const _PlanCard(
      {required this.plan, required this.subject, required this.date});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(widget.subject.colorHex);
    final goalMinutes = widget.plan.goalMinutes;
    final hasTime = widget.plan.targetDate.hour != 0 ||
        widget.plan.targetDate.minute != 0;

    String subtitle;
    if (hasTime) {
      final startTime = TimeOfDay(
          hour: widget.plan.targetDate.hour,
          minute: widget.plan.targetDate.minute);
      final endTotalMinutes =
          startTime.hour * 60 + startTime.minute + goalMinutes;
      final endTime = TimeOfDay(
          hour: (endTotalMinutes ~/ 60) % 24,
          minute: endTotalMinutes % 60);
      subtitle =
      '${startTime.format(context)} → ${endTime.format(context)} ($goalMinutes분)';
    } else {
      subtitle = '목표: ${goalMinutes}분';
    }
    if (widget.plan.memo.isNotEmpty) subtitle += ' · ${widget.plan.memo}';

    return GestureDetector(
      onLongPress: () => setState(() => _showDelete = !_showDelete),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _showDelete
              ? Colors.red.shade50
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showDelete
                ? Colors.red.shade200
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(Icons.book, color: color, size: 20),
          ),
          title: Text(widget.subject.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: _showDelete
              ? IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await ref
                  .read(studyPlanViewModelProvider(widget.date)
                  .notifier)
                  .deletePlan(widget.plan.id);
            },
          )
              : null,
        ),
      ),
    );
  }
}

// ── 세션 카드 (길게 누르면 삭제) ──────────────────────────
class _SessionCard extends ConsumerStatefulWidget {
  final StudySession session;
  final Subject subject;
  final DateTime date;
  const _SessionCard(
      {required this.session, required this.subject, required this.date});

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(widget.subject.colorHex);
    final minutes = widget.session.durationSeconds ~/ 60;
    final seconds = widget.session.durationSeconds % 60;
    final timeStr = widget.session.endTime == null
        ? '진행 중...'
        : '$minutes분 ${seconds}초';

    // 시작 시각 표시
    final startStr =
    DateFormat('HH:mm').format(widget.session.startTime);

    return GestureDetector(
      onLongPress: () => setState(() => _showDelete = !_showDelete),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _showDelete
              ? Colors.red.shade50
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _showDelete
                ? Colors.red.shade200
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(Icons.timer, color: color, size: 20),
          ),
          title: Text(widget.subject.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '$startStr 시작 · $timeStr · 폰 꺼냄 ${widget.session.trayOpenCount}회'),
          trailing: _showDelete
              ? IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              await ref
                  .read(studySessionViewModelProvider(widget.date)
                  .notifier)
                  .deleteSession(widget.session.id);
              ref.invalidate(statsViewModelProvider);
            },
          )
              : widget.session.endTime == null
              ? const Icon(Icons.circle,
              color: Colors.green, size: 12)
              : null,
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.indigo;
  }
}