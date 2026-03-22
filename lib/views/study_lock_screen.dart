import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../viewmodels/study_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../viewmodels/study_view_model.dart';

class StudyLockScreen extends ConsumerStatefulWidget {
  final String sessionId;
  final Subject subject;

  const StudyLockScreen({
    super.key,
    required this.sessionId,
    required this.subject,
  });

  @override
  ConsumerState<StudyLockScreen> createState() => _StudyLockScreenState();
}

class _StudyLockScreenState extends ConsumerState<StudyLockScreen>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _elapsedSeconds = 0;

  // 밀어서 해제 드래그 상태
  double _dragOffset = 0;
  static const double _maxDrag = 220;
  bool _unlocking = false;

  // 시계
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // 동기부여 문구
  final List<String> _quotes = [
    '집중하는 지금 이 순간이\n미래를 만들어요 💪',
    '조금만 더, 할 수 있어요 🔥',
    '폰은 잠시 내려두고\n공부에 집중해요 📚',
    '오늘의 노력이\n내일의 차이를 만들어요 ✨',
    '지금 이 순간을\n후회 없이 써봐요 🎯',
  ];
  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 화면 꺼짐 방지
    _currentQuote = (_quotes..shuffle()).first;

    // 공부 타이머
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // 시계 업데이트
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _clockTimer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  String get _timeString {
    final h = _elapsedSeconds ~/ 3600;
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _endStudy() async {
    setState(() => _unlocking = true);

    final selectedDate = ref.read(selectedDateProvider);
    await ref
        .read(studySessionViewModelProvider(selectedDate).notifier)
        .endSession(widget.sessionId, _elapsedSeconds);

    ref.read(activeSessionIdProvider.notifier).setSession(null);
    ref.invalidate(statsViewModelProvider);  // ← 이 줄 추가

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(widget.subject.colorHex);
    final progress = _dragOffset / _maxDrag;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 배경 그라데이션 ──────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.3 + progress * 0.3),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // ── 메인 콘텐츠 ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),

                // 현재 시각
                Text(
                  DateFormat('HH:mm').format(_now),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_now),
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                ),

                const SizedBox(height: 48),

                // 과목 표시
                CircleAvatar(
                  radius: 36,
                  backgroundColor: color.withOpacity(0.3),
                  child: Icon(Icons.book, color: color, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subject.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 32),

                // 공부 타이머
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '공부 중',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeString,
                        style: TextStyle(
                          color: color,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 동기부여 문구
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _currentQuote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),

                const Spacer(),

                // ── 밀어서 잠금 해제 ──────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: _UnlockSlider(
                    onUnlock: _endStudy,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // 잠금 해제 중 오버레이
          if (_unlocking)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 밀어서 잠금 해제 슬라이더 ─────────────────────────────
class _UnlockSlider extends StatefulWidget {
  final VoidCallback onUnlock;
  final Color color;

  const _UnlockSlider({required this.onUnlock, required this.color});

  @override
  State<_UnlockSlider> createState() => _UnlockSliderState();
}

class _UnlockSliderState extends State<_UnlockSlider>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  bool _completed = false;

  static const double _thumbSize = 56;
  static const double _trackHeight = 64;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bounceAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_completed) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, maxDrag);
    });

    if (_dragX >= maxDrag) {
      _completed = true;
      widget.onUnlock();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_completed) return;
    // 완료 안 됐으면 원위치 애니메이션
    _bounceController.forward(from: 0).then((_) {
      setState(() => _dragX = 0);
      _bounceController.reset();
    });
    setState(() => _dragX = 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _thumbSize - 8;
        final progress = _dragX / maxDrag;

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(color: Colors.white24),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 채워지는 배경
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _dragX + _thumbSize + 8,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.25 * progress),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),

              // 텍스트 힌트
              Center(
                child: Opacity(
                  opacity: (1 - progress * 2).clamp(0.0, 1.0),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                      SizedBox(width: 4),
                      Text(
                        '밀어서 공부 종료',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // 드래그 썸
              Positioned(
                left: _dragX + 4,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: _onDragEnd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      progress >= 0.9 ? Icons.check : Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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