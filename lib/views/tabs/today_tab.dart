import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';
import '../../main.dart' show database;
import '../study_lock_screen.dart';

// ── 월별 계획 날짜 Provider ───────────────────────────────
final planDatesInMonthProvider =
FutureProvider.family<Set<DateTime>, DateTime>((ref, monthKey) async {
  return database.getPlanDatesInMonth(monthKey.year, monthKey.month);
});

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

  // ── 월 달력 팝업 ─────────────────────────────────────
  Future<void> _showMonthCalendar(
      BuildContext context, DateTime currentMonth, Set<DateTime> planDates) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthCalendarDialog(
        initialMonth: currentMonth,
        planDates: planDates,
        selectedDate: ref.read(selectedDateProvider),
      ),
    );
    if (picked != null) {
      _selectDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final plansAsync = ref.watch(studyPlanViewModelProvider(selectedDate));
    final sessionsAsync = ref.watch(studySessionViewModelProvider(selectedDate));
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final days = _weekDays;

    // 주간 바에서 보이는 달 기준으로 계획 날짜 조회 (첫 번째 날 기준)
    final monthKey = DateTime(_weekStart.year, _weekStart.month);
    final planDatesAsync = ref.watch(planDatesInMonthProvider(monthKey));
    // 주가 두 달에 걸치면 마지막 날의 달도 조회
    final lastDay = days.last;
    final lastMonthKey = DateTime(lastDay.year, lastDay.month);
    final planDatesLastAsync = lastMonthKey != monthKey
        ? ref.watch(planDatesInMonthProvider(lastMonthKey))
        : null;

    final Set<DateTime> planDates = {
      ...planDatesAsync.valueOrNull ?? {},
      ...planDatesLastAsync?.valueOrNull ?? {},
    };

    // selectedDate 기준 월의 계획 날짜 (달력 팝업용)
    final selMonthKey = DateTime(selectedDate.year, selectedDate.month);
    final selPlanDatesAsync = ref.watch(planDatesInMonthProvider(selMonthKey));

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
                        child: GestureDetector(
                          onTap: () => _showMonthCalendar(
                            context,
                            DateTime(selectedDate.year, selectedDate.month),
                            selPlanDatesAsync.valueOrNull ?? {},
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                monthLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.calendar_month,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                        ),
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
                      final hasPlan = planDates.contains(date);

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
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
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
                              // ── 계획 있는 날 빨간 점 ────────────────
                              if (hasPlan)
                                Positioned(
                                  top: 0,
                                  right: 2,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                // ── 계획 헤더 (추가 + 전체 삭제) ──────────
                plansAsync.when(
                  data: (plans) => Row(
                    children: [
                      Expanded(
                        child: _SectionHeader(
                          title: '오늘의 계획',
                          onAdd: () =>
                              _showAddPlanDialog(context, ref, selectedDate),
                        ),
                      ),
                      if (plans.isNotEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              _confirmDeleteAllPlans(context, ref, selectedDate),
                          icon: const Icon(Icons.delete_sweep,
                              size: 16, color: Colors.redAccent),
                          label: const Text('전체 삭제',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.redAccent)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  loading: () => _SectionHeader(
                    title: '오늘의 계획',
                    onAdd: () =>
                        _showAddPlanDialog(context, ref, selectedDate),
                  ),
                  error: (_, __) => _SectionHeader(
                    title: '오늘의 계획',
                    onAdd: () =>
                        _showAddPlanDialog(context, ref, selectedDate),
                  ),
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

  // ── 계획 전체 삭제 확인 ──────────────────────────────
  Future<void> _confirmDeleteAllPlans(
      BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계획 전체 삭제'),
        content: Text(
          '${DateFormat('M월 d일', 'ko').format(selectedDate)}의\n'
              '모든 계획을 삭제할까요?\n\n이 작업은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('전체 삭제',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref
        .read(studyPlanViewModelProvider(selectedDate).notifier)
        .deleteAllPlansForDate(selectedDate);

    // 계획 날짜 캐시 갱신
    final monthKey = DateTime(selectedDate.year, selectedDate.month);
    ref.invalidate(planDatesInMonthProvider(monthKey));
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
          // 계획 날짜 캐시 갱신
          final monthKey = DateTime(selectedDate.year, selectedDate.month);
          ref.invalidate(planDatesInMonthProvider(monthKey));
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

// ══════════════════════════════════════════════════════════════
// 월 달력 다이얼로그
// ══════════════════════════════════════════════════════════════

class _MonthCalendarDialog extends StatefulWidget {
  final DateTime initialMonth;
  final Set<DateTime> planDates;
  final DateTime selectedDate;

  const _MonthCalendarDialog({
    required this.initialMonth,
    required this.planDates,
    required this.selectedDate,
  });

  @override
  State<_MonthCalendarDialog> createState() => _MonthCalendarDialogState();
}

class _MonthCalendarDialogState extends State<_MonthCalendarDialog> {
  late DateTime _displayMonth;
  Set<DateTime> _planDates = {};
  bool _loadingDates = false;

  @override
  void initState() {
    super.initState();
    _displayMonth = widget.initialMonth;
    _planDates = widget.planDates;
  }

  Future<void> _loadDatesForMonth(DateTime month) async {
    setState(() => _loadingDates = true);
    final dates = await database.getPlanDatesInMonth(month.year, month.month);
    if (mounted) setState(() { _planDates = dates; _loadingDates = false; });
  }

  void _prevMonth() {
    final prev = DateTime(_displayMonth.year, _displayMonth.month - 1);
    setState(() => _displayMonth = prev);
    _loadDatesForMonth(prev);
  }

  void _nextMonth() {
    final next = DateTime(_displayMonth.year, _displayMonth.month + 1);
    setState(() => _displayMonth = next);
    _loadDatesForMonth(next);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    // 달력 시작: 해당 월 1일의 요일 맞추기 (월=1 기준)
    final startOffset = firstDay.weekday - 1; // 0=월, 6=일
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 월 네비게이션
            Row(
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    DateFormat('yyyy년 M월', 'ko').format(_displayMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 요일 헤더
            Row(
              children: ['월', '화', '수', '목', '금', '토', '일'].map((d) {
                Color c = Colors.grey;
                if (d == '토') c = Colors.blue;
                if (d == '일') c = Colors.red;
                return Expanded(
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            // 날짜 그리드
            if (_loadingDates)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else
              ...List.generate(rows, (rowIdx) {
                return Row(
                  children: List.generate(7, (colIdx) {
                    final cellIdx = rowIdx * 7 + colIdx;
                    final dayNum = cellIdx - startOffset + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 44));
                    }
                    final date = DateTime(
                        _displayMonth.year, _displayMonth.month, dayNum);
                    final isSelected = date == widget.selectedDate;
                    final isToday = date == today;
                    final hasPlan = _planDates.contains(date);
                    final isSat = date.weekday == DateTime.saturday;
                    final isSun = date.weekday == DateTime.sunday;

                    Color numColor;
                    if (isSelected) numColor = Colors.white;
                    else if (isToday) numColor = Theme.of(context).colorScheme.primary;
                    else if (isSat) numColor = Colors.blue;
                    else if (isSun) numColor = Colors.red;
                    else numColor = Theme.of(context).colorScheme.onSurface;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, date),
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              margin: const EdgeInsets.all(3),
                              height: 38,
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
                              alignment: Alignment.center,
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: numColor,
                                ),
                              ),
                            ),
                            // 계획 있는 날 빨간 점
                            if (hasPlan)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 계획 추가 다이얼로그
// ══════════════════════════════════════════════════════════════

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

// ── 계획 카드 ─────────────────────────────────────────────
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
              // 계획 날짜 캐시 갱신
              final monthKey = DateTime(
                  widget.date.year, widget.date.month);
              ref.invalidate(planDatesInMonthProvider(monthKey));
            },
          )
              : null,
        ),
      ),
    );
  }
}

// ── 세션 카드 ─────────────────────────────────────────────
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