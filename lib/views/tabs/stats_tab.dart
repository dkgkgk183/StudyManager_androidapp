import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/study_view_model.dart';
import '../../database/database.dart';

class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _listController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _listController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _ringController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _listController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(statsViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: statsAsync.when(
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

            // trigger animations once data is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_ringController.isAnimating) _startAnimations();
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── 원형 시간표 ──────────────────────────────
                  _buildRingChart(stats, totalSeconds),

                  const SizedBox(height: 24),

                  // ── 과목별 카드 (스태거 애니메이션) ──────────
                  ...stats.asMap().entries.map((entry) {
                    return _buildAnimatedCard(entry.key, entry.value,
                        totalSeconds, stats.length);
                  }),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }

  // ── 원형 시간표 ──────────────────────────────────────────
  Widget _buildRingChart(
      List<Map<String, dynamic>> stats, int totalSeconds) {
    return AnimatedBuilder(
      animation: _ringController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: _RingChartPainter(
            stats: stats,
            totalSeconds: totalSeconds,
            progress: CurvedAnimation(
              parent: _ringController,
              curve: Curves.easeOutCubic,
            ).value,
            pulseValue: _pulseController.value,
          ),
        );
      },
    );
  }

  // ── 과목별 카드 ─────────────────────────────────────────
  Widget _buildAnimatedCard(int index, Map<String, dynamic> item,
      int totalSeconds, int totalCount) {
    final subject = item['subject'] as Subject;
    final seconds = item['totalSeconds'] as int;
    final ratio = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
    final color = _colorFromHex(subject.colorHex);

    final delay = index * 0.15;
    final animation = CurvedAnimation(
      parent: _listController,
      curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3 + 0.3 * _pulseController.value),
                              blurRadius: 4 + 4 * _pulseController.value,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(subject.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(_formatDuration(seconds),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      )),
                  const SizedBox(width: 6),
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── 애니메이션 프로그레스 바 ────────────────────
              AnimatedBuilder(
                animation: _ringController,
                builder: (context, _) {
                  final barProgress = CurvedAnimation(
                    parent: _ringController,
                    curve: Curves.easeOutCubic,
                  ).value;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio * barProgress,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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

// ── 원형 차트 페인터 ──────────────────────────────────────
class _RingChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> stats;
  final int totalSeconds;
  final double progress; // 0.0 → 1.0
  final double pulseValue;

  _RingChartPainter({
    required this.stats,
    required this.totalSeconds,
    required this.progress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;
    const strokeWidth = 22.0;

    // 배경 링
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.06);
    canvas.drawCircle(center, radius, bgPaint);

    if (totalSeconds == 0) return;

    // 과목별 세그먼트
    double startAngle = -pi / 2;
    final sweepTotal = 2 * pi * progress;

    for (final item in stats) {
      final seconds = item['totalSeconds'] as int;
      if (seconds == 0) continue;

      final subject = item['subject'] as Subject;
      final color = _colorFromHex(subject.colorHex);
      final ratio = seconds / totalSeconds;
      final sweep = sweepTotal * ratio;

      // 메인 세그먼트
      final segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.03, // 세그먼트 사이 간격
        false,
        segmentPaint,
      );

      // 글로우 효과
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..color = color.withOpacity(0.15 + 0.1 * pulseValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.03,
        false,
        glowPaint,
      );

      startAngle += sweep;
    }

    // 중앙 텍스트
    final totalPainter = TextPainter(
      text: TextSpan(
        text: _formatTotal(totalSeconds),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    totalPainter.paint(
      canvas,
      Offset(center.dx - totalPainter.width / 2,
          center.dy - totalPainter.height / 2 - 10),
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: '총 공부 시간',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2,
          center.dy + totalPainter.height / 2 - 6),
    );
  }

  String _formatTotal(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter old) =>
      old.progress != progress || old.pulseValue != pulseValue;
}

Color _colorFromHex(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.indigo;
  }
}
