import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';
import '../../main.dart' show database;
import 'package:drift/drift.dart' show Value;
import '../../services/study_service.dart';

// ── 월별 체크리스트 날짜 Provider ──────────────────────────
final checklistDatesInMonthProvider =
FutureProvider.family<Set<DateTime>, DateTime>((ref, monthKey) async {
  return database.getChecklistDatesInMonth(monthKey.year, monthKey.month);
});

class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key});

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab>
    with TickerProviderStateMixin {
  late DateTime _weekStart;

  // ── 공부 모드 상태 ──────────────────────────────────────
  bool _isStudyActive = false;
  int _studySeconds = 0;
  Timer? _studyTimer;
  String? _sessionId;
  String? _selectedSubjectId;
  String _studySubjectName = '';

  // ── 깜빡임 애니메이션 ─────────────────────────────────
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    final now = DateTime.now();
    final effectiveDate = now.hour < 6
        ? DateTime(now.year, now.month, now.day - 1)
        : DateTime(now.year, now.month, now.day);
    _weekStart = _getMonday(effectiveDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedDateProvider.notifier).setDate(effectiveDate);
    });
    _closeOrphanedSessions();
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _blinkController.dispose();
    super.dispose();
  }

  /// 이전 실행에서 종료되지 않은 세션 정리 (비정상 종료 복구)
  Future<void> _closeOrphanedSessions() async {
    try {
      final sessions = await database.getAllSessions();
      bool hasOrphan = false;

      final endTimeMillis = await StudyService.getEndTimeMillis();
      final savedSeconds = await StudyService.getElapsedSeconds();
      final endTime = endTimeMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(endTimeMillis)
          : DateTime.now();

      for (final s in sessions) {
        if (s.endTime == null) {
          hasOrphan = true;
          final elapsed = savedSeconds ?? endTime.difference(s.startTime).inSeconds;
          final updated = s.copyWith(
            endTime: Value(endTime),
            durationSeconds: elapsed,
          );
          await database.updateSession(updated);
        }
      }

      await StudyService.clearEndTime();

      if (hasOrphan && mounted) {
        final selectedDate = ref.read(selectedDateProvider);
        ref.invalidate(studySessionViewModelProvider(selectedDate));
        await ref.read(studySessionViewModelProvider(selectedDate).future);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  // ── 공부 모드 메서드 ────────────────────────────────────
  Future<void> _startStudy() async {
    if (_selectedSubjectId == null) return;

    final selectedDate = ref.read(selectedDateProvider);
    final checklistAsync = ref.read(todayChecklistViewModelProvider(selectedDate));
    final items = checklistAsync.valueOrNull;
    if (items == null || items.isEmpty) return;

    final subjectItem = items.firstWhere(
        (e) => (e['subject'] as Subject).id == _selectedSubjectId);
    final subject = subjectItem['subject'] as Subject;

    final sessionId = await ref
        .read(studySessionViewModelProvider(selectedDate).notifier)
        .startSession(subjectId: subject.id);

    setState(() {
      _isStudyActive = true;
      _studySeconds = 0;
      _sessionId = sessionId;
      _studySubjectName = subject.name;
    });

    // 포그라운드 서비스 시작
    await StudyService.startService(subject.name);

    _studyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _studySeconds++);
        StudyService.updateTime(_studySeconds);
      }
    });
  }

  Future<void> _endStudy() async {
    _studyTimer?.cancel();
    await StudyService.stopService();

    final sessionId = _sessionId;
    final studySeconds = _studySeconds;

    if (mounted) {
      setState(() {
        _isStudyActive = false;
        _sessionId = null;
        _selectedSubjectId = null;
        _studySubjectName = '';
      });
    }

    final selectedDate = ref.read(selectedDateProvider);

    if (sessionId != null) {
      await ref
          .read(studySessionViewModelProvider(selectedDate).notifier)
          .endSession(sessionId, studySeconds);
    }

    ref.invalidate(studySessionViewModelProvider(selectedDate));
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    setState(() {
      _weekStart = monday;
      _selectedSubjectId = null;
    });
  }

  Future<void> _showMonthCalendar(
      BuildContext context, DateTime currentMonth, Set<DateTime> checklistDates) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthCalendarDialog(
        initialMonth: currentMonth,
        checklistDates: checklistDates,
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
    final checklistAsync = ref.watch(todayChecklistViewModelProvider(selectedDate));
    final sessionsAsync = ref.watch(studySessionViewModelProvider(selectedDate));
    final today = toStudyDate(DateTime.now());
    final days = _weekDays;

    final monthKey = DateTime(_weekStart.year, _weekStart.month);
    final checklistDatesAsync = ref.watch(checklistDatesInMonthProvider(monthKey));
    final lastDay = days.last;
    final lastMonthKey = DateTime(lastDay.year, lastDay.month);
    final checklistDatesLastAsync = lastMonthKey != monthKey
        ? ref.watch(checklistDatesInMonthProvider(lastMonthKey))
        : null;

    final Set<DateTime> checklistDates = {
      ...checklistDatesAsync.valueOrNull ?? {},
      ...checklistDatesLastAsync?.valueOrNull ?? {},
    };

    final selMonthKey = DateTime(selectedDate.year, selectedDate.month);
    final selChecklistDatesAsync = ref.watch(checklistDatesInMonthProvider(selMonthKey));

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
                            selChecklistDatesAsync.valueOrNull ?? {},
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
                      final hasChecklist = checklistDates.contains(date);

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
                                width: double.infinity,
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
                              // ── 체크리스트 있는 날 빨간 점 ──────────
                              if (hasChecklist)
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
                // ── 체크리스트 헤더 (추가 + 전체 삭제) ───
                checklistAsync.when(
                  data: (items) => Row(
                    children: [
                      Expanded(
                        child: _SectionHeader(
                          title: '오늘의 체크리스트',
                          onAdd: () =>
                              _showAddChecklistDialog(context, ref, selectedDate),
                        ),
                      ),
                      if (items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              _confirmDeleteAllChecklists(context, ref, selectedDate),
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
                    title: '오늘의 체크리스트',
                    onAdd: () =>
                        _showAddChecklistDialog(context, ref, selectedDate),
                  ),
                  error: (_, __) => _SectionHeader(
                    title: '오늘의 체크리스트',
                    onAdd: () =>
                        _showAddChecklistDialog(context, ref, selectedDate),
                  ),
                ),
                const SizedBox(height: 8),
                // ── 공부 상태 배너 ──────────────────────────
                if (_isStudyActive)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.school,
                            size: 36, color: Colors.green),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: _blinkController,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '열공 중!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '공부 시간: ${_formatTime(_studySeconds)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                checklistAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptyHint(
                          message: 'AI 탭에서 체크리스트를 만들거나\n직접 추가해보세요');
                    }
                    // 과목별 그룹핑
                    final grouped = <String, List<Map<String, dynamic>>>{};
                    final subjectMap = <String, Subject>{};
                    for (final item in items) {
                      final subject = item['subject'] as Subject;
                      grouped.putIfAbsent(subject.id, () => []).add(item);
                      subjectMap[subject.id] = subject;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        final subject = subjectMap[entry.key]!;
                        final color = _colorFromHex(subject.colorHex);
                        final groupItems = entry.value;
                        final isSelected =
                            _selectedSubjectId == subject.id;
                        return GestureDetector(
                          onTap: _isStudyActive
                              ? null
                              : () {
                                  setState(() {
                                    _selectedSubjectId =
                                        isSelected ? null : subject.id;
                                  });
                                },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? color.withOpacity(0.05)
                                  : Colors.transparent,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 과목 헤더
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color,
                                        radius: 8,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        subject.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${groupItems.length}개',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (!_isStudyActive)
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? color
                                              : Colors.grey.shade400,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // 체크리스트 항목들 (드래그 정렬)
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: groupItems.length,
                                    onReorder: (oldIndex, newIndex) {
                                      if (newIndex > oldIndex) newIndex--;
                                      ref
                                          .read(todayChecklistViewModelProvider(selectedDate)
                                              .notifier)
                                          .reorderInSubject(subject.id, oldIndex, newIndex);
                                    },
                                    proxyDecorator: (child, index, animation) =>
                                        Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(8),
                                          child: child,
                                        ),
                                    itemBuilder: (context, index) {
                                      final checklistItem =
                                          groupItems[index]['item'] as ChecklistItem;
                                      return _ChecklistItemTile(
                                        key: ValueKey(checklistItem.id),
                                        item: checklistItem,
                                        subject: subject,
                                        date: selectedDate,
                                        index: index,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () =>
                  const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('오류: $e'),
                ),
                // ── 공부 시작/종료 버튼 ─────────────────
                checklistAsync.when(
                  data: (items) {
                    if (items.isEmpty && !_isStudyActive) {
                      return const SizedBox.shrink();
                    }
                    final hasRecords =
                        sessionsAsync.valueOrNull?.isNotEmpty == true;
                    if (_isStudyActive) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ElevatedButton.icon(
                          onPressed: _endStudy,
                          icon: const Icon(Icons.stop),
                          label: const Text('공부 종료'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ElevatedButton.icon(
                        onPressed: _selectedSubjectId != null
                            ? _startStudy
                            : null,
                        icon: const Icon(Icons.school),
                        label: Text(hasRecords ? '공부 재개' : '공부 시작'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
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
    );
  }

  // ── 체크리스트 전체 삭제 확인 ──────────────────────────
  Future<void> _confirmDeleteAllChecklists(
      BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체크리스트 전체 삭제'),
        content: Text(
          '${DateFormat('M월 d일', 'ko').format(selectedDate)}의\n'
              '모든 체크리스트를 삭제할까요?\n\n이 작업은 되돌릴 수 없어요.',
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
        .read(todayChecklistViewModelProvider(selectedDate).notifier)
        .deleteAll();

    final monthKey = DateTime(selectedDate.year, selectedDate.month);
    ref.invalidate(checklistDatesInMonthProvider(monthKey));
  }

  // ── 체크리스트 추가 ──────────────────────────────────────
  Future<void> _showAddChecklistDialog(
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
      builder: (context) => _AddChecklistDialog(
        selectedDate: selectedDate,
        validCategories: validCategories,
        onAdd: ({
          required String subjectId,
          required String text,
        }) async {
          await ref
              .read(todayChecklistViewModelProvider(selectedDate).notifier)
              .addItem(subjectId, text);
          final monthKey = DateTime(selectedDate.year, selectedDate.month);
          ref.invalidate(checklistDatesInMonthProvider(monthKey));
        },
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════
// 월 달력 다이얼로그
// ══════════════════════════════════════════════════════════════

class _MonthCalendarDialog extends StatefulWidget {
  final DateTime initialMonth;
  final Set<DateTime> checklistDates;
  final DateTime selectedDate;

  const _MonthCalendarDialog({
    required this.initialMonth,
    required this.checklistDates,
    required this.selectedDate,
  });

  @override
  State<_MonthCalendarDialog> createState() => _MonthCalendarDialogState();
}

class _MonthCalendarDialogState extends State<_MonthCalendarDialog> {
  late DateTime _displayMonth;
  Set<DateTime> _checklistDates = {};
  bool _loadingDates = false;

  @override
  void initState() {
    super.initState();
    _displayMonth = widget.initialMonth;
    _checklistDates = widget.checklistDates;
  }

  Future<void> _loadDatesForMonth(DateTime month) async {
    setState(() => _loadingDates = true);
    final dates = await database.getChecklistDatesInMonth(month.year, month.month);
    if (mounted) setState(() { _checklistDates = dates; _loadingDates = false; });
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
    final today = toStudyDate(DateTime.now());
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final startOffset = firstDay.weekday - 1;
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
                    final hasChecklist = _checklistDates.contains(date);
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
                            // 체크리스트 있는 날 빨간 점
                            if (hasChecklist)
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
// 체크리스트 추가 다이얼로그
// ══════════════════════════════════════════════════════════════

class _AddChecklistDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> validCategories;
  final Future<void> Function({
  required String subjectId,
  required String text,
  }) onAdd;

  const _AddChecklistDialog({
    required this.selectedDate,
    required this.validCategories,
    required this.onAdd,
  });

  @override
  State<_AddChecklistDialog> createState() => _AddChecklistDialogState();
}

class _AddChecklistDialogState extends State<_AddChecklistDialog> {
  late Map<String, dynamic> _selectedCategory;
  late Subject _selectedSubject;
  final _textCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.validCategories.first;
    _selectedSubject =
        (_selectedCategory['subjects'] as List<Subject>).first;
    _textCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  List<Subject> get _currentSubjects =>
      _selectedCategory['subjects'] as List<Subject>;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('체크리스트 추가'),
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
            const Text('할 일',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            TextField(
              controller: _textCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '예: 교과서 3장 풀기',
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
          onPressed: (_isLoading || _textCtrl.text.isEmpty)
              ? null
              : () async {
            setState(() => _isLoading = true);
            await widget.onAdd(
              subjectId: _selectedSubject.id,
              text: _textCtrl.text,
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
          subtitle: Text('$startStr 시작 · $timeStr'),
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

// ── 체크리스트 항목 타일 ─────────────────────────────────
class _ChecklistItemTile extends ConsumerStatefulWidget {
  final ChecklistItem item;
  final Subject subject;
  final DateTime date;
  final int index;
  const _ChecklistItemTile(
      {super.key, required this.item, required this.subject, required this.date, required this.index});

  @override
  ConsumerState<_ChecklistItemTile> createState() =>
      _ChecklistItemTileState();
}

class _ChecklistItemTileState extends ConsumerState<_ChecklistItemTile> {
  bool _showDelete = false;

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(widget.subject.colorHex);

    return GestureDetector(
      onLongPress: () => setState(() => _showDelete = !_showDelete),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: widget.index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.drag_handle,
                    size: 20, color: Colors.grey.shade400),
              ),
            ),
            Checkbox(
              value: widget.item.isChecked,
              activeColor: color,
              onChanged: (value) async {
                await ref
                    .read(todayChecklistViewModelProvider(widget.date).notifier)
                    .toggleItem(widget.item.id, value ?? false);
              },
            ),
            Expanded(
              child: Text(
                widget.item.content,
                style: TextStyle(
                  decoration:
                      widget.item.isChecked ? TextDecoration.lineThrough : null,
                  color: widget.item.isChecked ? Colors.grey : null,
                ),
              ),
            ),
            if (_showDelete)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                onPressed: () async {
                  await ref
                      .read(todayChecklistViewModelProvider(widget.date)
                          .notifier)
                      .deleteItem(widget.item.id);
                },
              ),
          ],
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
