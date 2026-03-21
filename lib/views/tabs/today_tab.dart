import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';

class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(selectedDateProvider);
    final plansAsync = ref.watch(studyPlanViewModelProvider(today));
    final sessionsAsync = ref.watch(studySessionViewModelProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko').format(today)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: today,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).setDate(picked);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 오늘의 계획 섹션 ──────────────────────────────
          _SectionHeader(
            title: '오늘의 계획',
            onAdd: () => _showAddPlanDialog(context, ref, today),
          ),
          const SizedBox(height: 8),
          plansAsync.when(
            data: (plans) {
              if (plans.isEmpty) {
                return const _EmptyHint(message: 'AI 탭에서 계획을 만들거나\n직접 추가해보세요');
              }
              return Column(
                children: plans.map((item) {
                  final plan = item['plan'] as StudyPlan;
                  final subject = item['subject'] as Subject;
                  return _PlanCard(plan: plan, subject: subject, date: today);
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('오류: $e'),
          ),

          const SizedBox(height: 24),

          // ── 오늘의 공부 기록 섹션 ─────────────────────────
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
                  return _SessionCard(session: session, subject: subject, date: today);
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('오류: $e'),
          ),

          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartSessionDialog(context, ref),
        icon: const Icon(Icons.play_arrow),
        label: const Text('공부 시작'),
      ),
    );
  }

  // ── 계획 추가 다이얼로그 ────────────────────────────────
  void _showAddPlanDialog(BuildContext context, WidgetRef ref, DateTime date) {
    final subjectsAsync = ref.read(subjectViewModelProvider);
    subjectsAsync.whenData((subjects) {
      if (subjects.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 설정에서 과목을 추가해주세요')),
        );
        return;
      }

      String selectedSubjectId = subjects.first.id;
      final goalCtrl = TextEditingController(text: '60');
      final memoCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('계획 추가'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: '과목', isDense: true),
                  items: subjects
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedSubjectId = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: goalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '목표 시간 (분)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(studyPlanViewModelProvider(date).notifier)
                      .addPlan(
                        subjectId: selectedSubjectId,
                        targetDate: date,
                        goalMinutes: int.tryParse(goalCtrl.text) ?? 60,
                        memo: memoCtrl.text,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('추가'),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── 세션 시작 다이얼로그 ────────────────────────────────
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
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final today = ref.read(selectedDateProvider);
                  final id = await ref
                      .read(studySessionViewModelProvider(today).notifier)
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

// ── 재사용 위젯들 ─────────────────────────────────────────
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
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500),
      ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.book, color: color, size: 20),
        ),
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('목표: ${plan.goalMinutes}분${plan.memo.isNotEmpty ? ' · ${plan.memo}' : ''}'),
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
    final timeStr = session.endTime == null
        ? '진행 중...'
        : '$minutes분 ${seconds}초';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.timer, color: color, size: 20),
        ),
        title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '$timeStr · 폰 꺼냄 ${session.trayOpenCount}회',
        ),
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
