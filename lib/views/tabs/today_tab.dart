import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';

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
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
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
                        dayNumColor = Theme.of(context).colorScheme.onSurface;
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
                                  ? Theme.of(context).colorScheme.primaryContainer
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
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
                                            : Theme.of(context).colorScheme.primary,
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
                  onAdd: () => _showAddPlanDialog(context, ref, selectedDate),
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
                        return _PlanCard(plan: plan, subject: subject, date: selectedDate);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                        return _SessionCard(session: session, subject: subject, date: selectedDate);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('오류: $e'),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartSessionDialog(context, ref),
        icon: const Icon(Icons.play_arrow),
        label: const Text('공부 시작'),
      ),
    );
  }

  // ── 계획 추가 다이얼로그 ──────────────────────────────
  Future<void> _showAddPlanDialog(
      BuildContext context, WidgetRef ref, DateTime selectedDate) async {
    final categoryList = await ref.read(categoryViewModelProvider.future);

    // 과목이 하나라도 있는 카테고리만 필터
    final validCategories = categoryList
        .where((c) => (c['subjects'] as List<Subject>).isNotEmpty)
        .toList();

    if (!context.mounted) return;

    // 카테고리/과목이 없으면 안내
    if (validCategories.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('과목이 없어요'),
          content: const Text('설정 탭에서 카테고리와 과목을 먼저 추가해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    // 다이얼로그 표시
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
          await ref.read(studyPlanViewModelProvider(selectedDate).notifier).addPlan(
            subjectId: subjectId,
            targetDate: targetDate,
            goalMinutes: goalMinutes,
            memo: memo,
          );
        },
      ),
    );
  }

  void _showStartSessionDialog(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.read(subjectViewModelProvider);
    subjectsAsync.whenData((subjects) {
      if (subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 설정에서 과목을 추가해주세요')),
        );
        return;
      }
      String selectedSubjectId = subjects.first.id;
      final selectedDate = ref.read(selectedDateProvider);

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('공부 시작'),
            content: DropdownButtonFormField<String>(
              value: selectedSubjectId,
              decoration: const InputDecoration(labelText: '과목', isDense: true),
              items: subjects
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => selectedSubjectId = v!),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: () async {
                  final id = await ref
                      .read(studySessionViewModelProvider(selectedDate).notifier)
                      .startSession(subjectId: selectedSubjectId);
                  ref.read(activeSessionIdProvider.notifier).setSession(id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('시작'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── 계획 추가 다이얼로그 위젯 ─────────────────────────────
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
    _selectedSubject = (_selectedCategory['subjects'] as List<Subject>).first;
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  List<Subject> get _currentSubjects =>
      _selectedCategory['subjects'] as List<Subject>;

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final isToday = widget.selectedDate ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

    if (picked == null) return;

    // 오늘 날짜인 경우 현재 시간 이전은 불가
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
    return AlertDialog(
      title: const Text('계획 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 선택
            const Text('카테고리', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: _selectedCategory,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: widget.validCategories.map((c) {
                final cat = c['category'] as SubjectCategory;
                return DropdownMenuItem(value: c, child: Text(cat.name));
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _selectedCategory = v;
                  _selectedSubject = (_selectedCategory['subjects'] as List<Subject>).first;
                });
              },
            ),

            const SizedBox(height: 12),

            // 과목 선택
            const Text('과목', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            DropdownButtonFormField<Subject>(
              value: _selectedSubject,
              decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              items: _currentSubjects.map((s) {
                final color = _colorFromHex(s.colorHex);
                return DropdownMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: color, radius: 6),
                      const SizedBox(width: 8),
                      Text(s.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedSubject = v);
              },
            ),

            const SizedBox(height: 12),

            // 시간 선택
            const Text('시작 시간', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
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
                          : '시간 선택 (선택 사항)',
                      style: TextStyle(
                        color: _selectedTime != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedTime != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedTime = null),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 목표 시간
            const Text('목표 공부 시간', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

            const SizedBox(height: 12),

            // 메모
            const Text('메모', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
            setState(() => _isLoading = true);
            // 시간 반영: 시간 선택 시 해당 시간, 아니면 자정(00:00)
            final targetDate = _selectedTime != null
                ? DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
              _selectedTime!.hour,
              _selectedTime!.minute,
            )
                : widget.selectedDate;

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
            child: CircularProgressIndicator(strokeWidth: 2),
          )
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

class _PlanCard extends ConsumerWidget {
  final StudyPlan plan;
  final Subject subject;
  final DateTime date;
  const _PlanCard({required this.plan, required this.subject, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorFromHex(subject.colorHex);
    // 시간이 설정된 경우 표시
    final hasTime = plan.targetDate.hour != 0 || plan.targetDate.minute != 0;
    final timeStr = hasTime
        ? ' · ${TimeOfDay(hour: plan.targetDate.hour, minute: plan.targetDate.minute).format(context)}'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.book, color: color, size: 20),
        ),
        title: Text(subject.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '목표: ${plan.goalMinutes}분$timeStr${plan.memo.isNotEmpty ? ' · ${plan.memo}' : ''}'),
        trailing: Checkbox(
          value: plan.isCompleted,
          onChanged: (v) => ref
              .read(studyPlanViewModelProvider(date).notifier)
              .toggleComplete(plan.id, v ?? false),
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  final StudySession session;
  final Subject subject;
  final DateTime date;
  const _SessionCard({required this.session, required this.subject, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorFromHex(subject.colorHex);
    final minutes = session.durationSeconds ~/ 60;
    final seconds = session.durationSeconds % 60;
    final timeStr = session.endTime == null ? '진행 중...' : '$minutes분 ${seconds}초';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.timer, color: color, size: 20),
        ),
        title: Text(subject.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$timeStr · 폰 꺼냄 ${session.trayOpenCount}회'),
        trailing: session.endTime == null
            ? const Icon(Icons.circle, color: Colors.green, size: 12)
            : null,
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