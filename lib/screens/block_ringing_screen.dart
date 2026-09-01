import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/routine_block.dart';
import '../services/alarm_sound_service.dart';
import '../services/focus_dnd_service.dart';
import '../services/alarm_vibration_service.dart';
import '../services/notification_service.dart';
import '../services/routine_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_labels.dart';
import '../widgets/subject_icon.dart';
import '../widgets/wake_card.dart';
import 'focus_setup_screen.dart';

/// Design 4o -- "a block is about to start".
///
/// Light and tinted to the subject, deliberately unlike the wake alarm's dark
/// lock screen: a routine alarm can be snoozed or skipped, and it should not
/// look like the one alarm you cannot escape.
class BlockRingingScreen extends StatefulWidget {
  final RoutineBlock block;

  const BlockRingingScreen({super.key, required this.block});

  @override
  State<BlockRingingScreen> createState() => _BlockRingingScreenState();
}

class _BlockRingingScreenState extends State<BlockRingingScreen> {
  final _sound = AlarmSoundService();
  final _vibration = AlarmVibrationService();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startAlarmAudio();
    _vibration.start();
  }

  /// See RingingScreen._startAlarmAudio -- the ring service has been playing
  /// since the block fired, and it keeps playing rather than handing over.
  Future<void> _startAlarmAudio() async {
    await FocusDndService.instance.boostAlarmVolume();
    if (await FocusDndService.instance.isNativeRinging()) return;
    if (!mounted) return;
    await _sound.start();
  }

  @override
  void dispose() {
    _sound.dispose();
    _vibration.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _stopRinging() async {
    await _sound.stop();
    await FocusDndService.instance.stopNativeRing();
    await FocusDndService.instance.restoreAlarmVolume();
    await _vibration.stop();
    // The notification is ongoing and insistent, so it keeps sounding until
    // it is explicitly taken down.
    await NotificationService.instance.cancelBlockNotification(widget.block.id);
    await NotificationService.instance.clearPendingRingBlockId();
  }

  Future<void> _skipToday() async {
    await _stopRinging();
    // Nothing else to undo: the block already re-armed itself for its next
    // occurrence when it fired, so skipping today leaves the routine intact.
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snooze() async {
    await _stopRinging();
    await NotificationService.instance
        .snoozeBlock(widget.block, const Duration(minutes: 5));
    if (mounted) Navigator.of(context).pop();
  }

  /// A personal block (gym, a walk) does not want a focus session, it just
  /// wants the phone to stop asking for attention.
  Future<void> _silencePhone() async {
    await _stopRinging();
    await FocusDndService.instance.setEnabled(true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _startFocus() async {
    await _stopRinging();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FocusSetupScreen(
          initialSubject: _heading,
          block: widget.block,
        ),
      ),
    );
  }

  /// "Physics — rotational motion" reads as a big "Physics" with the detail
  /// underneath, exactly as the design splits it.
  String get _heading => widget.block.title.split('—').first.trim();

  String? get _detail {
    final parts = widget.block.title.split('—');
    if (parts.length < 2) return null;
    final rest = parts.sublist(1).join('—').trim();
    return rest.isEmpty ? null : rest;
  }

  /// The subject drives the tint, so Physics reads blue and Chemistry green
  /// the way they do everywhere else in the app.
  Color _tint(WakeColors c) {
    final t = _heading.toLowerCase();
    if (t.contains('physics')) return c.physics;
    if (t.contains('chem')) return c.done;
    if (t.contains('math')) return c.accent;
    switch (widget.block.type) {
      case BlockType.study:
        return c.accent;
      case BlockType.breakTime:
        return c.done;
      case BlockType.personal:
        return c.personal;
    }
  }

  /// Subjects use the app-wide glyph so Physics is the same atom here as on
  /// an alarm row; anything else falls back to a glyph for its block type.
  Widget _glyph(Color color) {
    final subject =
        subjectGlyphForTitle(_heading, size: 30, color: color);
    if (subject != null) return subject;
    final fallback = switch (widget.block.type) {
      BlockType.study => Icons.menu_book_outlined,
      BlockType.breakTime => Icons.restaurant_outlined,
      BlockType.personal => Icons.fitness_center,
    };
    return Icon(fallback, size: 30, color: color);
  }

  String _durationLabel() {
    final m = widget.block.durationMinutes;
    if (m % 60 == 0) return '${m ~/ 60} hour${m == 60 ? '' : 's'}';
    if (m < 60) return '$m minutes';
    return '${m ~/ 60}h ${m % 60}m';
  }

  String _startsIn(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    final delta = widget.block.startMinute - minute;
    if (delta > 0) return 'starts in $delta minute${delta == 1 ? '' : 's'}';
    if (delta == 0) return 'starts now';
    return 'started ${-delta} minute${delta == -1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final block = widget.block;
    final now = DateTime.now();
    final tint = _tint(c);
    final routine = context.read<RoutineProvider>();

    final studyToday =
        routine.blocksFor(now).where((b) => b.type.canFocus).toList();
    final indexToday = studyToday.indexWhere((b) => b.id == block.id);
    final next = routine.nextBlockAfter(now);

    final footnotes = <String>[];
    if (next != null) {
      footnotes.add(
        '${next.title.split('—').first.trim()} follows at '
        '${RoutineBlock.formatMinute(next.startMinute)}.',
      );
    }
    if (indexToday >= 0 && studyToday.length > 1) {
      footnotes.add(
        'Today is ${indexToday + 1} of ${studyToday.length} study blocks.',
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // A soft wash in the subject's colour, fading into the page.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 420,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tint.withValues(alpha: 0.16),
                      tint.withValues(alpha: 0.0),
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
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: tint.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: tint),
                          ),
                          const SizedBox(width: 8),
                          Text('ROUTINE ALARM', style: sectionLabelStyle(tint)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    Text(
                      RoutineBlock.formatMinute(block.startMinute -
                          block.remindBeforeMinutes),
                      style: numberStyle(fontSize: 56, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(longDateLabel(now), style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.gap),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      alignment: Alignment.center,
                      child: _glyph(tint),
                    ),
                    const SizedBox(height: AppSpacing.gapTight),
                    Text(_heading,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${_startsIn(now)} · ${block.timeRangeLabel}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),

                    WakeCard(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _IconTile(
                                  icon: Icons.calendar_today_outlined,
                                  color: tint),
                              const SizedBox(width: AppSpacing.gapTight),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_detail ?? block.type.label,
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${block.type.label} · ${_durationLabel()} '
                                      '· repeats ${repeatSummary(block.days)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (footnotes.isNotEmpty) ...[
                            Divider(
                                height: AppSpacing.gap, color: c.divider),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _IconTile(
                                    icon: Icons.schedule, color: c.textMuted),
                                const SizedBox(width: AppSpacing.gapTight),
                                Expanded(
                                  child: Text(footnotes.join(' '),
                                      style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.gapTight),

                    // Each block type asks for something different: a study
                    // block starts focus, a break asks you to actually step
                    // away, and a personal block just wants the phone quiet.
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: switch (block.type) {
                        BlockType.study => FilledButton(
                            onPressed: _startFocus,
                            child: const Text('Start focus now  →'),
                          ),
                        BlockType.breakTime => FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: c.textPrimary,
                              foregroundColor: c.bg,
                            ),
                            onPressed: _skipToday,
                            child: const Text('Start break'),
                          ),
                        BlockType.personal => FilledButton(
                            onPressed: _silencePhone,
                            child: const Text('Silence my phone'),
                          ),
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _snooze,
                              child: const Text('Snooze 5 min'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _skipToday,
                              child: const Text('Skip today'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Routine alarms can be snoozed or skipped — only wake '
                      'missions lock the phone.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconTile({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}
