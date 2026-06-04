import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../viewmodels/ui_state.dart';
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
            // ── 본문 (지금은 비어 있음) ─────────────────
            const Expanded(
              child: SizedBox.shrink(),
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
