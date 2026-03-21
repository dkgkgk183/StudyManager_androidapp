import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';

class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('공부 통계')),
      body: statsAsync.when(
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(
              child: Text(
                '아직 공부 기록이 없어요.\n오늘 탭에서 공부를 시작해보세요!',
                textAlign: TextAlign.center,
              ),
            );
          }

          final totalSeconds = stats.fold<int>(
              0, (sum, item) => sum + (item['totalSeconds'] as int));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 총 공부 시간 카드 ────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '총 공부 시간',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(totalSeconds),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── 과목별 통계 ───────────────────────────────
              Text('과목별 공부 시간',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...stats.map((item) {
                final subject = item['subject'] as Subject;
                final seconds = item['totalSeconds'] as int;
                final ratio = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
                final color = _colorFromHex(subject.colorHex);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: color,
                            ),
                            const SizedBox(width: 8),
                            Text(subject.name,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text(_formatDuration(seconds),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('오류: $e')),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    return '$m분';
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
