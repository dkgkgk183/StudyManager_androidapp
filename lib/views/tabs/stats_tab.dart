import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';
import '../../viewmodels/focus_briefing_view_model.dart';
import 'today_tab.dart' show checklistDatesInMonthProvider;

class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  bool _calendarExpanded = false;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(
      ref.read(selectedDateProvider).year,
      ref.read(selectedDateProvider).month,
    );
  }

  void _toggleCalendar() {
    setState(() {
      _calendarExpanded = !_calendarExpanded;
      if (_calendarExpanded) {
        final selected = ref.read(selectedDateProvider);
        _displayMonth = DateTime(selected.year, selected.month);
      }
    });
  }

  void _prevMonth() {
    setState(() => _displayMonth =
        DateTime(_displayMonth.year, _displayMonth.month - 1));
  }

  void _nextMonth() {
    setState(() => _displayMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1));
  }

  void _selectDate(DateTime date) {
    ref.read(selectedDateProvider.notifier).setDate(date);
    setState(() {
      _calendarExpanded = false;
      _displayMonth = DateTime(date.year, date.month);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final today = toStudyDate(DateTime.now());
    final checklistDatesAsync =
        ref.watch(checklistDatesInMonthProvider(_displayMonth));
    final checklistDates = checklistDatesAsync.valueOrNull ?? <DateTime>{};

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 상단 날짜 버튼 ─────────────────────────
            InkWell(
              onTap: _toggleCalendar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('yyyy년 M월 d일 (E)', 'ko').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _calendarExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.expand_more, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            // ── 슬라이드 캘린더 ─────────────────────────
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _calendarExpanded
                    ? _buildCalendar(
                        context, today, selectedDate, checklistDates)
                    : const SizedBox(width: double.infinity),
              ),
            ),
            const Divider(height: 1),
            // ── 오늘의 기록 ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _DailySummary(date: selectedDate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    DateTime today,
    DateTime selectedDate,
    Set<DateTime> checklistDates,
  ) {
    final firstDay =
        DateTime(_displayMonth.year, _displayMonth.month, 1);
    final startOffset = firstDay.weekday - 1; // 월요일 시작
    final daysInMonth =
        DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 요일 헤더
          Row(
            children: ['월', '화', '수', '목', '금', '토', '일'].map((d) {
              Color c = Colors.grey;
              if (d == '토') c = Colors.blue;
              if (d == '일') c = Colors.red;
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: c,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // 날짜 그리드
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
                final isSelected = date == selectedDate;
                final isToday = date == today;
                final hasChecklist = checklistDates.contains(date);
                final isSat = date.weekday == DateTime.saturday;
                final isSun = date.weekday == DateTime.sunday;

                Color numColor;
                if (isSelected) {
                  numColor = Colors.white;
                } else if (isToday) {
                  numColor = Theme.of(context).colorScheme.primary;
                } else if (isSat) {
                  numColor = Colors.blue;
                } else if (isSun) {
                  numColor = Colors.red;
                } else {
                  numColor = Theme.of(context).colorScheme.onSurface;
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(date),
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
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .surface,
                                  width: 1.2,
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
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 오늘의 기록
// ══════════════════════════════════════════════════════════════

class _SubjectSegment {
  final Subject subject;
  final int seconds;
  const _SubjectSegment(this.subject, this.seconds);
}

class _DailySummary extends ConsumerWidget {
  final DateTime date;
  const _DailySummary({required this.date});

  List<_SubjectSegment> _buildSegments(
    Set<Subject> checklistSubjects,
    List<Map<String, dynamic>> sessions,
  ) {
    final secondsBySubject = <String, int>{};
    for (final entry in sessions) {
      final session = entry['session'] as StudySession;
      final subject = entry['subject'] as Subject;
      if (checklistSubjects.contains(subject)) {
        secondsBySubject[subject.id] =
            (secondsBySubject[subject.id] ?? 0) + session.durationSeconds;
      }
    }
    final segs = checklistSubjects
        .map((s) => _SubjectSegment(s, secondsBySubject[s.id] ?? 0))
        .where((s) => s.seconds > 0)
        .toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    return segs;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistAsync = ref.watch(todayChecklistViewModelProvider(date));
    final sessionsAsync = ref.watch(studySessionViewModelProvider(date));
    final summaryAsync = ref.watch(statsSummaryViewModelProvider(date));
    final summary = summaryAsync.valueOrNull ?? StatsSummary.empty;

    final isLoading = checklistAsync.isLoading || sessionsAsync.isLoading;

    // 체크리스트에 등장한 과목만 추출
    final checklistSubjects = <Subject>{};
    for (final item in (checklistAsync.valueOrNull ?? const [])) {
      checklistSubjects.add(item['subject'] as Subject);
    }

    final segments = _buildSegments(
      checklistSubjects,
      sessionsAsync.valueOrNull ?? const [],
    );
    final gaugeTotal = segments.fold<int>(0, (s, e) => s + e.seconds);

    // 들어올림은 DB에 실제 기록된 횟수 그대로 사용한다.
    // (공부 종료 시 마지막 들어올림은 _pendingTrayOpen으로 버려지므로
    // trayOpenCountLocal은 "진짜로 흐름이 끊긴 횟수"에 해당한다.)
    final phoneLiftCount =
        summary.trayOpenCountLocal + summary.trayOpenCountRpi;

    // 집중도 점수 (3타일 + 공부 시간 기반)
    final hasStudy = summary.sessionCount > 0;
    final focusScore = StatsSummary.computeFocusScore(
      sessionCount: summary.sessionCount,
      phoneLiftCount: phoneLiftCount,
      penaltyCount: summary.penaltyCount,
      totalSeconds: summary.totalSeconds,
    );

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '오늘의 기록',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        // ── 과목별 원형 게이지 ─────────────────────
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _SubjectGauge(
                    segments: segments,
                    totalSeconds: gaugeTotal,
                    centerText: gaugeTotal == 0
                        ? '기록 없음'
                        : _formatDuration(gaugeTotal),
                    centerColor: theme.colorScheme.primary,
                    trackColor: theme.colorScheme.surfaceContainerHighest,
                  ),
          ),
        ),
        // ── 과목 범례 ──────────────────────────────
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: segments.map((seg) {
              final color = _colorFromHex(seg.subject.colorHex);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${seg.subject.name} ${_formatDuration(seg.seconds)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
        // ── 출처 비율 (게이지 옆 미니 인디케이터) ───
        if (summary.sessionCount > 0) ...[
          const SizedBox(height: 14),
          _SourceBreakdown(
            localSeconds: summary.totalSecondsLocal,
            rpiSeconds: summary.totalSecondsRpi,
          ),
        ],
        const SizedBox(height: 16),
        // ── 집중도 점수 ──────────────────────────────
        if (summary.totalSeconds < 1800)
          _FocusScoreInsufficientNotice(
            minutes: (summary.totalSeconds / 60).floor(),
          )
        else
          _FocusScoreCard(
            score: focusScore,
            hasData: hasStudy,
            date: date,
          ),
        const SizedBox(height: 12),
        // ── 세션 개수 / 폰 들어올림 횟수 ──────────────
        const _SourceLegend(),
        const SizedBox(height: 6),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Expanded(
              child: _SummaryTile(
                icon: Icons.timer_outlined,
                iconColor: Colors.blue,
                label: '공부 세션',
                localValue: summary.sessionCountLocal,
                rpiValue: summary.sessionCountRpi,
                suffix: '개',
              ),
            ),
              const SizedBox(width: 12),
            Expanded(
              child: _SummaryTile(
                icon: Icons.smartphone,
                iconColor: Colors.orange,
                label: '폰 들어올림\n트레이 열림',
                localValue: summary.trayOpenCountLocal,
                rpiValue: summary.trayOpenCountRpi,
                suffix: '회',
              ),
            ),
              const SizedBox(width: 12),
            Expanded(
              child: _SummaryTile(
                icon: Icons.block,
                iconColor: Colors.red,
                label: '패널티',
                localValue: summary.penaltyCountLocal,
                rpiValue: summary.penaltyCountRpi,
                suffix: '회',
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectGauge extends StatelessWidget {
  final List<_SubjectSegment> segments;
  final int totalSeconds;
  final String centerText;
  final Color centerColor;
  final Color trackColor;

  const _SubjectGauge({
    required this.segments,
    required this.totalSeconds,
    required this.centerText,
    required this.centerColor,
    required this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size(200, 200),
          painter: _SubjectGaugePainter(
            segments: segments,
            totalSeconds: totalSeconds,
            trackColor: trackColor,
            strokeWidth: 18,
          ),
        ),
        Text(
          centerText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: centerColor,
          ),
        ),
      ],
    );
  }
}

class _SubjectGaugePainter extends CustomPainter {
  final List<_SubjectSegment> segments;
  final int totalSeconds;
  final Color trackColor;
  final double strokeWidth;

  _SubjectGaugePainter({
    required this.segments,
    required this.totalSeconds,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 트랙(배경 링)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (totalSeconds == 0) return;

    // 과목별 호 — 12시 방향부터 시계방향
    const gap = 0.04; // 라디안 (세그먼트 사이 간격)
    var startAngle = -3.141592653589793 / 2; // -π/2 = 12시

    for (final seg in segments) {
      final sweep = (seg.seconds / totalSeconds) * 2 * 3.141592653589793;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = _colorFromHex(seg.subject.colorHex);

      canvas.drawArc(rect, startAngle + gap / 2, sweep - gap, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SubjectGaugePainter old) {
    return old.segments != segments || old.totalSeconds != totalSeconds;
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

class _FocusScoreInsufficientNotice extends StatelessWidget {
  final int minutes;
  const _FocusScoreInsufficientNotice({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '집중도',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '아직 ${30 - minutes}분 더 공부해야\n집중도 점수가 표시돼요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusScoreCard extends ConsumerWidget {
  final int score;
  final bool hasData;
  final DateTime date;

  const _FocusScoreCard({
    required this.score,
    required this.hasData,
    required this.date,
  });

  ({Color bg, Color fg, IconData icon, String status}) _resolve() {
    if (!hasData) {
      return (
        bg: Colors.grey.shade100,
        fg: Colors.grey.shade700,
        icon: Icons.remove_circle_outline,
        status: '측정 불가',
      );
    }
    if (score >= 90) {
      return (
        bg: Colors.green.shade50,
        fg: Colors.green.shade800,
        icon: Icons.star,
        status: '최우수',
      );
    }
    if (score >= 75) {
      return (
        bg: Colors.blue.shade50,
        fg: Colors.blue.shade800,
        icon: Icons.thumb_up,
        status: '양호',
      );
    }
    if (score >= 50) {
      return (
        bg: Colors.orange.shade50,
        fg: Colors.orange.shade800,
        icon: Icons.sentiment_satisfied,
        status: '보통',
      );
    }
    if (score >= 25) {
      return (
        bg: Colors.deepOrange.shade50,
        fg: Colors.deepOrange.shade800,
        icon: Icons.warning_amber,
        status: '주의',
      );
    }
    return (
      bg: Colors.red.shade50,
      fg: Colors.red.shade800,
      icon: Icons.dangerous,
      status: '위험',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = _resolve();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: r.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(r.icon, color: r.fg, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '집중도',
                    style: TextStyle(
                      fontSize: 12,
                      color: r.fg.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasData ? '$score점' : '—',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: r.fg,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                r.status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: r.fg,
                ),
              ),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: r.fg.withValues(alpha: 0.18),
            ),
            const SizedBox(height: 10),
            _AiBriefingSection(date: date, accentColor: r.fg),
          ],
        ],
      ),
    );
  }
}

class _AiBriefingSection extends ConsumerWidget {
  final DateTime date;
  final Color accentColor;

  const _AiBriefingSection({required this.date, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(focusBriefingProvider(date));
    return briefingAsync.when(
      data: (text) {
        final lines = text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final baseStyle = TextStyle(
          fontSize: 12.5,
          color: accentColor.withValues(alpha: 0.85),
          height: 1.45,
        );
        final boldStyle = TextStyle(
          fontSize: 12.5,
          color: accentColor,
          fontWeight: FontWeight.w700,
          height: 1.45,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: _parseBoldSpans(
                              line,
                              baseStyle,
                              boldStyle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
      loading: () => Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '브리핑을 생성하는 중...',
            style: TextStyle(
              fontSize: 12,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      error: (e, _) => Text(
        '브리핑을 불러올 수 없어요.',
        style: TextStyle(
          fontSize: 12,
          color: accentColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int localValue;
  final int rpiValue;
  final String suffix;

  const _SummaryTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.localValue,
    required this.rpiValue,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final rpiStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.teal.shade700,
    );
    final localStyle = const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$localValue$suffix', style: localStyle),
                  TextSpan(
                    text: ' / ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  TextSpan(text: '$rpiValue$suffix', style: rpiStyle),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 게이지 아래에 표시되는 시간 출처(로컬/트레이) 미니 인디케이터.
class _SourceBreakdown extends StatelessWidget {
  final int localSeconds;
  final int rpiSeconds;

  const _SourceBreakdown({
    required this.localSeconds,
    required this.rpiSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final total = localSeconds + rpiSeconds;
    final hasRpi = rpiSeconds > 0;
    final hasLocal = localSeconds > 0;
    final rpiRatio = total == 0 ? 0.0 : rpiSeconds / total;
    final rpiPercent = (rpiRatio * 100).round();

    return Column(
      children: [
        // 시간 분배 텍스트
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 2,
          children: [
            _durationChip(
              label: '로컬',
              seconds: localSeconds,
              color: Colors.grey.shade700,
              emphasized: !hasRpi && hasLocal,
            ),
            if (hasRpi) ...[
              const Text('·',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              _durationChip(
                label: '트레이',
                seconds: rpiSeconds,
                color: Colors.teal.shade700,
                emphasized: true,
              ),
            ],
            if (hasRpi) ...[
              const SizedBox(width: 4),
              Text(
                '($rpiPercent%)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // 미니 비율 막대
        if (total > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (hasLocal)
                      Expanded(
                        flex: localSeconds,
                        child: Container(color: Colors.grey.shade500),
                      ),
                    if (hasRpi)
                      Expanded(
                        flex: rpiSeconds,
                        child: Container(color: Colors.teal),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _durationChip({
    required String label,
    required int seconds,
    required Color color,
    required bool emphasized,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: emphasized ? 12 : 11,
          color: color,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
        ),
        children: [
          TextSpan(text: label),
          const TextSpan(text: ' '),
          TextSpan(
            text: _formatDuration(seconds),
            style: TextStyle(
              fontSize: emphasized ? 12 : 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3-타일의 "로컬/RPi" 표기 색상 안내.
class _SourceLegend extends StatelessWidget {
  const _SourceLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _legendDot(Colors.grey.shade700, '로컬'),
          const SizedBox(width: 12),
          _legendDot(Colors.teal.shade700, '트레이 (RPi)'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 초 단위 시간을 사람이 읽기 좋은 문자열로 포맷한다.
String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h시간 $m분 $s초';
  }
  if (m > 0) {
    return '$m분 $s초';
  }
  return '$s초';
}

/// `**텍스트**` 패턴을 굵은 스타일의 TextSpan으로 분리한다.
List<TextSpan> _parseBoldSpans(
  String text,
  TextStyle baseStyle,
  TextStyle boldStyle,
) {
  final spans = <TextSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*');
  int lastEnd = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: baseStyle));
    }
    spans.add(TextSpan(text: m.group(1), style: boldStyle));
    lastEnd = m.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }
  return spans;
}
