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

enum StudyMode { idle, waiting, active, paused }

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late DateTime _weekStart;

  // ── 공부 모드 상태 ──────────────────────────────────────
  StudyMode _studyMode = StudyMode.idle;
  final ValueNotifier<int> _studySeconds = ValueNotifier<int>(0);
  Timer? _studyTimer;
  String? _sessionId;
  String? _selectedSubjectId;
  String _studySubjectName = '';
  // ── 실제 경과 시간 추적 (Dart Timer throttling 회피) ──
  // 타이머는 1초마다 UI를 갱신하는 용도일 뿐, 실제 초 수는
  // wall-clock(_studySegmentStart + _accumulatedSegmentSeconds)으로 계산.
  DateTime? _studySegmentStart;
  int _accumulatedSegmentSeconds = 0;

  // ── 일시정지 모드 상태 ─────────────────────────────────
  final ValueNotifier<int> _pauseSeconds = ValueNotifier<int>(30);
  Timer? _pauseTimer;

  // ── 센서 ───────────────────────────────────────────────
  Timer? _sensorPollTimer;

  // ── 라이프사이클 구분 (잠금 vs 앱 전환) ─────────────────
  // inactive → paused가 수백ms 내 = 잠금화면(화면 끄기)
  // inactive → hidden → paused = 홈버튼/뒤로가기(앱 전환)
  DateTime? _inactiveAt;

  // ── 깜빡임 애니메이션 ─────────────────────────────────
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    final effectiveDate = toStudyDate(DateTime.now());
    _weekStart = _getMonday(effectiveDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedDateProvider.notifier).setDate(effectiveDate);
    });
    _closeOrphanedSessions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _studyTimer?.cancel();
    _pauseTimer?.cancel();
    _sensorPollTimer?.cancel();
    _studySeconds.dispose();
    _pauseSeconds.dispose();
    StudyService.stopSensor();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_studyMode != StudyMode.active && _studyMode != StudyMode.paused) {
      // 공부 중이 아니면 inactive 시점도 무시
      if (state == AppLifecycleState.inactive) _inactiveAt = null;
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _inactiveAt = DateTime.now();
      debugPrint('[Lifecycle] inactive 진입');
      return;
    }

    if (state != AppLifecycleState.paused) return;

    final inactiveAt = _inactiveAt;
    _inactiveAt = null;
    final elapsed = inactiveAt == null
        ? null
        : DateTime.now().difference(inactiveAt);

    // 잠금화면(화면 끄기): inactive에서 매우 짧은 시간 내 paused 도달
    // 앱 전환(홈/뒤로가기): inactive 후 더 길게 머무름
    if (elapsed != null && elapsed < const Duration(milliseconds: 500)) {
      debugPrint('[Lifecycle] paused (${elapsed.inMilliseconds}ms) → 잠금화면, 유지');
      return;
    }

    debugPrint('[Lifecycle] paused (${elapsed?.inMilliseconds}ms) → 앱 전환, 즉시 종료 + 패널티');
    if (_sessionId != null) {
      final selectedDate = ref.read(selectedDateProvider);
      await ref
          .read(studySessionViewModelProvider(selectedDate).notifier)
          .recordPenalty(_sessionId!);
    }
    await _endStudy();
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
      _studyMode = StudyMode.waiting;
      _studySeconds.value = 0;
      _sessionId = sessionId;
      _studySubjectName = subject.name;
    });

    // 포그라운드 서비스 시작 (대기 상태 알림)
    await StudyService.startService('대기 중...');

    // 가속도센서 시작 (뒤집기 감지)
    _startSensorListening();
  }

  void _startSensorListening() {
    _sensorPollTimer?.cancel();
    StudyService.startSensor();
    debugPrint('[Sensor] 센서 폴링 시작');

    _sensorPollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final z = await StudyService.getAccelZ();

      if (_studyMode == StudyMode.waiting && z < -9.5) {
        debugPrint('[Sensor] → 뒤집힘 감지! _startActiveStudy()');
        _startActiveStudy();
      } else if (_studyMode == StudyMode.paused && z < -9.5) {
        debugPrint('[Sensor] → 다시 뒤집힘! 공부 모드 복귀');
        _resumeActiveStudy();
      } else if (_studyMode == StudyMode.active && z > 0) {
        final locked = await StudyService.isKeyguardLocked();
        if (locked) {
          debugPrint('[Sensor] → 들어올림 but 잠금화면 → 무시');
        } else {
          debugPrint('[Sensor] → 들어올림 감지, _onPhoneLifted()');
          _onPhoneLifted();
        }
      }
    });
  }


  void _startActiveStudy() {
    debugPrint('[Study] _startActiveStudy() 호출됨');
    setState(() {
      _studyMode = StudyMode.active;
      _studySeconds.value = 0;
      _studySegmentStart = DateTime.now();
      _accumulatedSegmentSeconds = 0;
    });

    // 포그라운드 알림 갱신
    StudyService.startService(_studySubjectName);

    // 타이머는 wall-clock 기반 — Dart Timer가 OS에 의해 throttling되어도
    // 매 tick에서 실제 경과 시간을 다시 계산하므로 시간이 안 흘러보이지 않음.
    _studyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final total = _computeStudySeconds();
        _studySeconds.value = total;
        StudyService.updateTime(total);
      }
    });
  }

  /// 현재 활성 구간의 wall-clock 기반 경과 초 계산.
  /// (이전 active 구간 합 + 현재 active 구간 시작~지금)
  int _computeStudySeconds() {
    final segStart = _studySegmentStart;
    if (segStart == null) return _accumulatedSegmentSeconds;
    return _accumulatedSegmentSeconds +
        DateTime.now().difference(segStart).inSeconds;
  }

  void _onPhoneLifted() {
    debugPrint('[Study] _onPhoneLifted() mode=$_studyMode');
    if (_studyMode != StudyMode.active) return;

    // 폰이 들어올려진 횟수 1 증가 (Supabase tray_open_count로 동기화)
    if (_sessionId != null) {
      final selectedDate = ref.read(selectedDateProvider);
      ref
          .read(studySessionViewModelProvider(selectedDate).notifier)
          .recordTrayOpen(_sessionId!);
    }

    // 일시정지 진입: 현재 active 구간까지의 시간을 누적하고, 새 구간 시작을 멈춤.
    _studyTimer?.cancel();
    _studyTimer = null;
    final segStart = _studySegmentStart;
    if (segStart != null) {
      _accumulatedSegmentSeconds +=
          DateTime.now().difference(segStart).inSeconds;
      _studySegmentStart = null;
      _studySeconds.value = _accumulatedSegmentSeconds;
      StudyService.updateTime(_accumulatedSegmentSeconds);
    }

    setState(() {
      _studyMode = StudyMode.paused;
      _pauseSeconds.value = 30;
    });
    _pauseTimer?.cancel();
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      _pauseSeconds.value--;
      if (_pauseSeconds.value <= 0) {
        t.cancel();
        _applyPausePenalty();
      }
    });
  }

  void _resumeActiveStudy() {
    debugPrint('[Study] _resumeActiveStudy()');
    _pauseTimer?.cancel();
    // 새 active 구간 시작: segment start를 now로 갱신, 누적값은 보존.
    _studySegmentStart = DateTime.now();
    setState(() => _studyMode = StudyMode.active);
    StudyService.updateTime(_studySeconds.value);

    // (혹시 타이머가 없으면) 재시작
    if (_studyTimer == null) {
      _studyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          final total = _computeStudySeconds();
          _studySeconds.value = total;
          StudyService.updateTime(total);
        }
      });
    }
  }

  Future<void> _applyPausePenalty() async {
    if (_sessionId != null) {
      final selectedDate = ref.read(selectedDateProvider);
      await ref
          .read(studySessionViewModelProvider(selectedDate).notifier)
          .recordPenalty(_sessionId!);
    }

    if (mounted) setState(() => _studyMode = StudyMode.active);
  }

  Future<void> _endStudy() async {
    _studyTimer?.cancel();
    _studyTimer = null;
    _pauseTimer?.cancel();
    _sensorPollTimer?.cancel();
    _sensorPollTimer = null;
    await StudyService.stopSensor();
    await StudyService.stopService();

    final sessionId = _sessionId;
    // 종료 시점 wall-clock 기반 최종값 사용 (throttling 영향 없음)
    final studySeconds = _computeStudySeconds();
    _accumulatedSegmentSeconds = 0;
    _studySegmentStart = null;
    _studySeconds.value = studySeconds;

    if (mounted) {
      setState(() {
        _studyMode = StudyMode.idle;
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
      body: SafeArea(
        child: Column(
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
                if (_studyMode == StudyMode.waiting)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.phone_android,
                            size: 36, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text(
                          '대기 중...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '폰을 뒤집어주세요',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (_studyMode == StudyMode.active)
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
                        ValueListenableBuilder<int>(
                          valueListenable: _studySeconds,
                          builder: (_, s, __) => Text(
                            '공부 시간: ${_formatTime(s)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_studyMode == StudyMode.paused)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _blinkController,
                          child: const Icon(Icons.warning,
                              size: 36, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<int>(
                          valueListenable: _pauseSeconds,
                          builder: (_, s, __) => Text(
                            '일시정지 중 (${s}초)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '체크리스트를 조정하거나 스마트폰을 다시 뒤집으세요!',
                          style: TextStyle(color: Colors.red),
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
                          onTap: _studyMode != StudyMode.idle
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
                                      if (_studyMode == StudyMode.idle)
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
                                      final isStudySubject = _selectedSubjectId == null || _selectedSubjectId == subject.id;
                                      return _ChecklistItemTile(
                                        key: ValueKey(checklistItem.id),
                                        item: checklistItem,
                                        subject: subject,
                                        date: selectedDate,
                                        index: index,
                                        enabled: isStudySubject && (_studyMode == StudyMode.active || _studyMode == StudyMode.paused),
                                        onChanged: () {},
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
                    if (items.isEmpty && _studyMode == StudyMode.idle) {
                      return const SizedBox.shrink();
                    }
                    final hasRecords =
                        sessionsAsync.valueOrNull?.isNotEmpty == true;
                    if (_studyMode != StudyMode.idle) {
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
    DateFormat('HH:mm').format(widget.session.startTime.toLocal());

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
            '$startStr 시작 · $timeStr'
            '${widget.session.penaltyCount > 0 ? '  · 패널티 ${widget.session.penaltyCount}회' : ''}',
          ),
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

// ── 체크리스트 수정 다이얼로그 ─────────────────────────────
//
// 외부에서 controller를 관리해서 dispose 시점이 꼬이면
// (다이얼로그 dismiss 애니메이션 중에 controller가 해제되면서)
// "TextEditingController was used after being disposed" 에러가 터짐.
// 자체 State에서 controller를 만들고 dispose()에서 해제하면
// 위젯 트리에서 완전히 제거된 뒤에 정리되므로 안전.
class _EditChecklistDialog extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onSaved;
  final VoidCallback onCancel;
  const _EditChecklistDialog({
    required this.initialContent,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<_EditChecklistDialog> createState() => _EditChecklistDialogState();
}

class _EditChecklistDialogState extends State<_EditChecklistDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('체크리스트 수정'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: null,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: '할 일 내용',
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isEmpty) return;
            widget.onSaved(text);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

// ── 체크리스트 항목 타일 ─────────────────────────────────
class _ChecklistItemTile extends ConsumerStatefulWidget {
  final ChecklistItem item;
  final Subject subject;
  final DateTime date;
  final int index;
  final bool enabled;
  final VoidCallback? onChanged;
  const _ChecklistItemTile(
      {super.key, required this.item, required this.subject, required this.date, required this.index, this.enabled = true, this.onChanged});

  @override
  ConsumerState<_ChecklistItemTile> createState() =>
      _ChecklistItemTileState();
}

class _ChecklistItemTileState extends ConsumerState<_ChecklistItemTile> {
  bool _showActions = false;

  Future<void> _showEditDialog() async {
    final itemId = widget.item.id;
    final date = widget.date;
    final initialContent = widget.item.content;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _EditChecklistDialog(
        initialContent: initialContent,
        onSaved: (text) => Navigator.pop(dialogContext, text),
        onCancel: () => Navigator.pop(dialogContext),
      ),
    );

    if (result == null || result.isEmpty) return;

    // 다이얼로그 dismiss + 위젯 트리 안정화 이후에 업데이트 실행.
    // 같은 프레임에서 ref.invalidateSelf()가 호출되면
    // ReorderableListView 아이템 unmount와 InheritedWidget dependents 정리가
    // race가 되어 '_dependents.isEmpty' assertion이 터질 수 있음.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref
          .read(todayChecklistViewModelProvider(date).notifier)
          .updateItemContent(itemId, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(widget.subject.colorHex);
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () => setState(() => _showActions = !_showActions),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: _showActions
              ? color.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _showActions
                ? color.withOpacity(0.5)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4, top: 2, bottom: 2),
          child: Row(
            children: [
              Checkbox(
                value: widget.item.isChecked,
                activeColor: color,
                onChanged: widget.enabled
                    ? (value) async {
                        await ref
                            .read(todayChecklistViewModelProvider(widget.date).notifier)
                            .toggleItem(widget.item.id, value ?? false);
                        widget.onChanged?.call();
                      }
                    : null,
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
              if (_showActions) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(Icons.edit_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  tooltip: '수정',
                  onPressed: _showEditDialog,
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: () async {
                    await ref
                        .read(todayChecklistViewModelProvider(widget.date)
                            .notifier)
                        .deleteItem(widget.item.id);
                  },
                ),
              ],
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle,
                      size: 20, color: Colors.grey.shade400),
                ),
              ),
            ],
          ),
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
