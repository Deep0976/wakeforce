import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/focus_session.dart';
import '../models/routine_block.dart';
import '../services/focus_dnd_service.dart';
import '../services/focus_provider.dart';
import '../services/routine_provider.dart';
import '../services/stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';
import 'focus_complete_screen.dart';

/// Full-screen, no tab bar -- a mode you are inside of.
class FocusRunningScreen extends StatefulWidget {
  final String subject;
  final FocusMode mode;
  final int goalMinutes;
  final RoutineBlock? block;
  final bool silence;

  /// Packages to cover while the session runs. Empty when the student hasn't
  /// granted usage access and overlay permission, in which case Focus falls
  /// back to DND only and the status line says so.
  final List<String> shieldPackages;


  const FocusRunningScreen({
    super.key,
    required this.subject,
    required this.mode,
    required this.goalMinutes,
    this.block,
    this.silence = false,
    this.shieldPackages = const [],
  });

  @override
  State<FocusRunningScreen> createState() => _FocusRunningScreenState();
}

class _FocusRunningScreenState extends State<FocusRunningScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  final DateTime _startedAt = DateTime.now();
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _finished = false;

  /// What DND actually did, not what was asked for -- the status line must
  /// not claim a silence the OS refused.
  bool _silenced = false;

  /// Incremented each time the app goes to the background mid-session.
  int _interruptions = 0;

  /// True once the native guard is actually running -- what happened, not
  /// what was asked for.
  bool _shielded = false;


  /// Per-app open counts, filled in when the guard stops.
  Map<String, int> _appOpens = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The screen is the session: if it sleeps, the student loses their place.
    WakelockPlus.enable();
    if (widget.silence) {
      FocusDndService.instance.setEnabled(true).then((ok) {
        if (mounted) setState(() => _silenced = ok);
      });
    }
    if (widget.shieldPackages.isNotEmpty) {
      FocusDndService.instance
          .startGuard(packages: widget.shieldPackages, block: true)
          .then((ok) {
        if (mounted) setState(() => _shielded = ok);
      });
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || !mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (widget.mode == FocusMode.goal &&
          _elapsed.inMinutes >= widget.goalMinutes) {
        _finish(reachedGoal: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app is the thing that actually breaks a focus session, and
    // unlike naming the app they switched to, it needs no permissions.
    if (state == AppLifecycleState.paused && !_finished) {
      _interruptions++;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    WakelockPlus.disable();
    // Always lift DND on the way out, including when the session is
    // abandoned -- leaving a student's phone silent afterwards would be
    // worse than never silencing it.
    if (_silenced) FocusDndService.instance.setEnabled(false);
    // Same for the shield: a foreground service left running after the
    // session would keep covering apps with no way back.
    if (_shielded) FocusDndService.instance.stopGuard();
    super.dispose();
  }

  Future<void> _finish({required bool reachedGoal}) async {
    if (_finished) return;
    _finished = true;
    _ticker?.cancel();

    // Captured before any await: if the widget unmounts while the guard is
    // stopping, the sitting must still be banked. Reading providers off
    // `context` after the await would drop the whole session -- the student
    // does the work and gets no XP for it.
    final focus = context.read<FocusProvider>();
    final stats = context.read<StatsProvider>();

    // Stop the guard before building the session so its tallies are final.
    if (_shielded) {
      _appOpens = await FocusDndService.instance.stopGuard();
      _shielded = false;
    }

    final session = FocusSession(
      id: focus.newId(),
      subject: widget.subject,
      mode: widget.mode,
      goalMinutes: widget.goalMinutes,
      actualSeconds: _elapsed.inSeconds,
      startedAt: _startedAt,
      reachedGoal: reachedGoal,
      wasSilenced: _silenced,
      interruptions: _interruptions,
      appOpens: _appOpens,
    );
    await focus.record(session);
    await stats.recordFocusSession(session);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => FocusCompleteScreen(session: session)),
    );
  }

  Future<void> _confirmEndEarly() async {
    final minutes = _elapsed.inMinutes;

    // Every sitting is recorded and every sitting gets its summary, however
    // short. This used to pop straight out below a minute, which meant a
    // 20-second session vanished: no record, no summary, nothing in Progress.
    // Only the "are you sure" prompt is skipped -- there is nothing to lose
    // by stopping after a few seconds, so asking is just friction.
    if (minutes < 1) {
      await _finish(reachedGoal: false);
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this session?'),
        content: Text(
          widget.mode == FocusMode.goal
              ? 'You are ${widget.goalMinutes - minutes} minutes short of your goal.'
              : 'You have focused for $minutes minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (leave == true) await _finish(reachedGoal: false);
  }

  String get _clock {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _clockSubtitle(RoutineBlock? block, DateTime now) {
    if (block != null && block.isActiveAt(now)) {
      final left = block.minutesRemainingAt(now);
      return '$left MIN TO ${RoutineBlock.formatMinute(block.endMinute)}';
    }
    return widget.mode == FocusMode.goal
        ? 'OF ${widget.goalMinutes} MIN'
        : 'COUNTING UP';
  }

  String _statusLine() {
    final parts = <String>[];
    parts.add(_silenced ? 'Phone quiet' : 'Phone not silenced');
    if (_shielded) {
      parts.add('${widget.shieldPackages.length} apps shielded');
    }
    return parts.join(' · ');
  }

  /// "Chemistry follows at 10:15. Reminder at 10:05." -- only shown when a
  /// block really does follow, rather than as permanent filler.
  String? _nextBlockLine(DateTime now) {
    final next = context.read<RoutineProvider>().nextBlockAfter(now);
    if (next == null) return null;
    final start = RoutineBlock.formatMinute(next.startMinute);
    if (next.remindBeforeMinutes > 0) {
      final remind = RoutineBlock.formatMinute(
        next.startMinute - next.remindBeforeMinutes,
      );
      return '${next.title} follows at $start. Reminder at $remind.';
    }
    return '${next.title} follows at $start.';
  }

  double get _progress {
    if (widget.mode == FocusMode.open || widget.goalMinutes == 0) return 0;
    return (_elapsed.inSeconds / (widget.goalMinutes * 60)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final block = widget.block;
    final now = DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEndEarly();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              children: [
                if (block != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'ROUTINE BLOCK · ${block.timeRangeLabel}',
                          style: sectionLabelStyle(c.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.done.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          block.isActiveAt(now) ? 'ON SCHEDULE' : 'OFF BLOCK',
                          style: sectionLabelStyle(c.done),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.gapTight),
                Text(
                  widget.subject,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),

                // The ring is the whole screen's anchor.
                SizedBox(
                  width: 244,
                  height: 244,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: widget.mode == FocusMode.goal
                                ? _progress
                                : 1,
                            track: c.divider,
                            fill: _paused ? c.textFaint : c.accent,
                            indeterminate: widget.mode == FocusMode.open,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _clock,
                            style: numberStyle(
                              fontSize: 40,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _clockSubtitle(block, now),
                            style: sectionLabelStyle(c.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.gapWide),

                WakeCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.cardTight,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _silenced ? c.done : c.textFaint,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          _statusLine(),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_interruptions > 0) ...[
                  const SizedBox(height: AppSpacing.gapTight),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatChip(
                        label: _interruptions == 1
                            ? '1 PULL AWAY'
                            : '$_interruptions PULLS AWAY',
                      ),
                    ],
                  ),
                ],
                const Spacer(),

                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _paused = !_paused),
                        style: OutlinedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        child: Icon(_paused ? Icons.play_arrow : Icons.pause),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gapTight),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _confirmEndEarly,
                          child: Text(
                            block == null ? 'End session' : 'End block early',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _paused
                      ? 'Paused — the clock is stopped.'
                      : (_nextBlockLine(now) ?? 'Keep the screen on.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;
  final bool indeterminate;

  _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.indeterminate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    if (indeterminate) return;

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.fill != fill ||
      old.track != track ||
      old.indeterminate != indeterminate;
}

/// The design's small pill counters under the status line.
class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.divider),
      ),
      child: Text(label, style: sectionLabelStyle(c.textMuted)),
    );
  }
}
