import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../missions/chemistry_mission.dart';
import '../missions/math_mission.dart';
import '../missions/photo_mission.dart';
import '../missions/physics_mission.dart';
import '../missions/quiz_mission.dart';
import '../missions/shake_mission.dart';
import '../models/alarm.dart';
import '../models/mission_type.dart';
import '../services/alarm_provider.dart';
import '../services/alarm_sound_service.dart';
import '../services/alarm_vibration_service.dart';
import '../services/focus_dnd_service.dart';
import '../services/notification_service.dart';
import '../services/stats_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_labels.dart';
import '../widgets/subject_icon.dart';
import '../widgets/wake_card.dart';
import 'mission_complete_screen.dart';

class RingingScreen extends StatefulWidget {
  final Alarm alarm;

  const RingingScreen({super.key, required this.alarm});

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> {
  final _soundService = AlarmSoundService();
  final _vibrationService = AlarmVibrationService();
  late final Timer _ticker;
  Duration _elapsed = Duration.zero;
  late Duration _remaining = _timeLimitFor(widget.alarm.difficulty);
  bool _missionComplete = false;
  /// False while the design-4e ringing panel is up, true once the student
  /// taps through to the mission.
  bool _started = false;
  bool _attemptRecorded = false;

  static Duration _timeLimitFor(MissionDifficulty difficulty) => switch (difficulty) {
        MissionDifficulty.easy => const Duration(minutes: 5),
        MissionDifficulty.medium => const Duration(minutes: 4),
        MissionDifficulty.hard => const Duration(minutes: 3),
        MissionDifficulty.advanced => const Duration(minutes: 2),
      };

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startAlarmAudio();
    // This screen is the alarm now, so the notification stands down to a
    // silent way back rather than ringing over the top of it.
    NotificationService.instance.quieten(
      widget.alarm.id,
      widget.alarm.label.isEmpty ? 'Wake up!' : widget.alarm.label,
    );
    // Skipped for the shake mission -- the vibration motor's own movement
    // would register on the accelerometer and complete it on its own.
    if (widget.alarm.missionType != MissionType.shake) {
      _vibrationService.start();
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        // Purely cosmetic pressure -- never blocks completing the mission,
        // an alarm app must never lock someone out of dismissing an alarm.
        // Only counts down once the mission is actually on screen: sitting on
        // the ringing panel should not eat the time to solve it.
        if (_started && _remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
    // Deferred one frame so `context.read` has a valid provider scope.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _attemptRecorded) return;
      _attemptRecorded = true;
      context.read<StatsProvider>().recordMissionAttempted();
    });
  }

  /// The ring service has been playing since the alarm fired. If it still is,
  /// leave it: one sound source for the whole ring means no seam when this
  /// screen arrives, and no chance of ending up on a different tone than the
  /// one the student has been hearing. Only when this screen is the first
  /// thing to ring -- tapped from a notification, service never started --
  /// does it play its own.
  Future<void> _startAlarmAudio() async {
    await FocusDndService.instance.boostAlarmVolume();
    if (await FocusDndService.instance.isNativeRinging()) return;
    if (!mounted) return;
    await _soundService.start();
  }

  /// The alarm is over. Everything that could be making noise stops here.
  Future<void> _stopAlarmAudio() async {
    await _soundService.stop();
    await FocusDndService.instance.stopNativeRing();
    await FocusDndService.instance.restoreAlarmVolume();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _stopAlarmAudio();
    _soundService.dispose();
    _vibrationService.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _onMissionComplete() async {
    if (_missionComplete) return;
    setState(() => _missionComplete = true);
    final statsProvider = context.read<StatsProvider>();
    final alarmProvider = context.read<AlarmProvider>();
    await _stopAlarmAudio();
    await _vibrationService.stop();
    await NotificationService.instance.dismissNotification(widget.alarm.id);
    // A one-time alarm has no legitimate "next" occurrence once it's fired --
    // nextOccurrence() would otherwise keep rolling it to tomorrow and it'd
    // linger in Upcoming Alarms/Next Mission forever. Disabling it (instead
    // of deleting) keeps it in the Alarms tab so it can be flipped back on
    // for a future date without re-entering its time/mission from scratch.
    if (!widget.alarm.isRepeating) {
      await alarmProvider.toggleAlarm(widget.alarm.id, false);
    }
    await FirebaseAnalytics.instance.logEvent(
      name: 'mission_completed',
      parameters: {
        'mission_type': widget.alarm.missionType.name,
        'difficulty': widget.alarm.difficulty.name,
        'seconds_to_complete': _elapsed.inSeconds,
      },
    );
    final xpEarned = await statsProvider.recordMissionCompleted(
      widget.alarm.missionType,
      widget.alarm.difficulty,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MissionCompleteScreen(
          xpEarned: xpEarned,
          currentStreak: statsProvider.stats.currentStreak,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildMission() {
    switch (widget.alarm.missionType) {
      case MissionType.math:
        return MathMission(
          difficulty: widget.alarm.difficulty,
          onComplete: _onMissionComplete,
        );
      case MissionType.physics:
        return PhysicsMission(
          difficulty: widget.alarm.difficulty,
          onComplete: _onMissionComplete,
        );
      case MissionType.shake:
        return ShakeMission(
          difficulty: widget.alarm.difficulty,
          onComplete: _onMissionComplete,
        );
      case MissionType.typing:
        return ChemistryMission(
          difficulty: widget.alarm.difficulty,
          onComplete: _onMissionComplete,
        );
      case MissionType.photo:
        return PhotoMission(
          difficulty: widget.alarm.difficulty,
          referencePhotoPath: widget.alarm.referencePhotoPath,
          onComplete: _onMissionComplete,
        );
    }
  }

  /// Design 4e is a screen in its own right -- the alarm announces itself
  /// first, and the mission only appears once the student commits. Kept as a
  /// phase of this screen rather than a route of its own so the sound,
  /// vibration and wakelock lifecycle all stay in one place.
  Widget _buildRingingPanel(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final alarm = widget.alarm;
    final streak = context.read<StatsProvider>().stats.currentStreak;
    // The subject owns the colour: Maths orange, Physics blue, Chemistry
    // green -- the same mapping as the alarm list and the mission picker.
    // This screen used to paint everything the app accent, so a Chemistry
    // alarm rang in orange and the colour told the student nothing.
    final tint = alarm.missionType.accentColor(c);

    return Stack(
      children: [
        // Warm glow behind the clock, per the design's lit-from-above look.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.75),
                radius: 1.0,
                colors: [
                  tint.withValues(alpha: 0.30),
                  c.bg.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.gap),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: tint.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('ALARM RINGING', style: sectionLabelStyle(tint)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  TimeOfDay(hour: alarm.hour, minute: alarm.minute)
                      .format(context),
                  style: numberStyle(fontSize: 64, color: c.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(longDateLabel(DateTime.now()),
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.card.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: missionGlyph(alarm.missionType,
                      size: 30, color: tint),
                ),
                const SizedBox(height: AppSpacing.gap),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    '${alarm.missionType.label} · ${_difficultyLabel(alarm.difficulty)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: tint, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Text(_missionRequirement(), style: theme.textTheme.bodySmall),
                const Spacer(),
                if (streak > 0)
                  WakeCard(
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Icon(Icons.local_fire_department,
                              size: 17, color: tint),
                        ),
                        const SizedBox(width: AppSpacing.gapTight),
                        Expanded(
                          child: Text(
                            '$streak-day streak on the line. Solving this '
                            'alarm makes it ${streak + 1}.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.gapTight),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    // The button carries the subject colour too, so the whole
                    // screen reads as one subject rather than an orange app
                    // with a green chip stuck on it.
                    style: FilledButton.styleFrom(
                      backgroundColor: tint,
                      foregroundColor: ThemeData.estimateBrightnessForColor(
                                  tint) ==
                              Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1A1614),
                    ),
                    onPressed: () => setState(() => _started = true),
                    child: const Text('Solve to stop alarm'),
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTight),
                Text('Snooze · locked for this alarm',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                  'Volume and dismiss are disabled until the mission is solved.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: c.textFaint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _difficultyLabel(MissionDifficulty d) => switch (d) {
        MissionDifficulty.easy => 'Easy',
        MissionDifficulty.medium => 'Medium',
        MissionDifficulty.hard => 'Hard',
        MissionDifficulty.advanced => 'Advanced',
      };

  String _missionRequirement() {
    switch (widget.alarm.missionType) {
      case MissionType.shake:
        return 'Shake your phone to stop this alarm';
      case MissionType.photo:
        return 'Match the reference photo to stop this alarm';
      case MissionType.math:
      case MissionType.physics:
      case MissionType.typing:
        final n = QuizMission.questionCountFor(widget.alarm.difficulty);
        return '$n ${n == 1 ? "question" : "questions"} to stop this alarm';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4m, the ringing panel, is dark whatever the app theme is -- it opens
    // at 6am in a dark room, and the design keeps it dark even in the light
    // theme document. The mission itself (4d) is a LIGHT screen and follows
    // the app theme: wrapping the whole screen in dark dragged the maths
    // question and its four options into dark mode with it.
    if (!_started) {
      return Theme(
        data: buildWakeForceDarkTheme(),
        child: Builder(
          builder: (themedContext) => PopScope(
            canPop: false,
            child: Scaffold(body: _buildRingingPanel(themedContext)),
          ),
        ),
      );
    }
    return _buildBody(context);
  }

  Widget _buildBody(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final accent = widget.alarm.missionType.accentColor(c);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('MISSION STARTED', style: sectionLabelStyle(accent)),
                ],
              ),
              const SizedBox(height: AppSpacing.gapTight),
              Text(
                TimeOfDay(hour: widget.alarm.hour, minute: widget.alarm.minute)
                    .format(context),
                style: numberStyle(fontSize: 30, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.alarm.label.isEmpty
                    ? widget.alarm.missionType.label
                    : widget.alarm.label,
                style: theme.textTheme.bodyMedium,
              ),
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.1),
                  child: SingleChildScrollView(child: _buildMission()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  AppSpacing.screen,
                ),
                child: WakeCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.card,
                    vertical: AppSpacing.cardTight,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: c.textMuted),
                      const SizedBox(width: AppSpacing.gapTight),
                      Expanded(
                        child: Text(
                          'Time remaining',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _formatDuration(_remaining),
                        style: numberStyle(fontSize: 18, color: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
