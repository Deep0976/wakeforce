import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_session.dart';
import '../models/routine_block.dart';
import '../services/focus_dnd_service.dart';
import '../services/focus_provider.dart';
import '../services/routine_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';

/// Leads with what was earned, then hands off to the next thing.
class FocusCompleteScreen extends StatefulWidget {
  final FocusSession session;

  const FocusCompleteScreen({super.key, required this.session});

  @override
  State<FocusCompleteScreen> createState() => _FocusCompleteScreenState();
}

class _FocusCompleteScreenState extends State<FocusCompleteScreen> {
  /// Airplane mode is the one guard the app cannot lift for the student, so
  /// the design ends the block by reminding them it is still on.
  bool _airplaneOn = false;

  FocusSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    FocusDndService.instance.isAirplaneOn().then((on) {
      if (mounted) setState(() => _airplaneOn = on);
    });
  }

  String get _duration => session.durationLabel;

  String _subtitle() {
    if (session.mode == FocusMode.open) {
      return '${session.subject} · open session';
    }
    final delta = session.actualMinutes - session.goalMinutes;
    if (delta >= 0) {
      return delta == 0
          ? '${session.subject} · goal met'
          : '${session.subject} · goal beaten by $delta minutes';
    }
    return '${session.subject} · ${-delta} minutes short of goal';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    // Null for an open session: no goal, so no percentage to show.
    final onTask = session.timeOnTask;

    return Scaffold(
      body: Stack(
        children: [
          // 4k opens on a soft green wash that fades into the page -- the
          // colour is the reward, so it sits behind the time, not in a chip.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 330,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.done.withValues(alpha: 0.22),
                    c.done.withValues(alpha: 0.0),
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
              const Spacer(),
              Text('BLOCK COMPLETE', style: sectionLabelStyle(c.done)),
              const SizedBox(height: AppSpacing.gapTight),
              Text(
                _duration,
                style: numberStyle(fontSize: 46, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _subtitle(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '+${session.xpEarned}',
                      label: 'XP earned',
                      color: c.done,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapTight),
                  Expanded(
                    child: _Stat(
                      value: onTask == null
                          ? '—'
                          : '${(onTask * 100).round()}%',
                      label: 'Time on task',
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapTight),
              if (session.appOpens.isNotEmpty)
                _PulledAtYou(opens: session.appOpens)
              else
                WakeCard(
                  child: Row(
                    children: [
                      Icon(
                        session.interruptions == 0
                            ? Icons.check_circle_outline
                            : Icons.exit_to_app,
                        size: 18,
                        color:
                            session.interruptions == 0 ? c.done : c.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          session.interruptions == 0
                              ? 'You stayed in the app the whole time.'
                              : 'You left the app ${session.interruptions} '
                                  '${session.interruptions == 1 ? "time" : "times"}.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_airplaneOn) ...[
                const SizedBox(height: AppSpacing.gapTight),
                WakeCard(
                  tint: c.accent,
                  child: Row(
                    children: [
                      Icon(Icons.airplanemode_active,
                          size: 18, color: c.accentInk),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Airplane mode is still on. Turn it off?',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed:
                            FocusDndService.instance.openAirplaneSettings,
                        child: Text('SETTINGS',
                            style: sectionLabelStyle(c.accentInk)),
                      ),
                    ],
                  ),
                ),
              ],
              _RoutineOnTrack(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Done'),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(
                  'Back to today\'s routine',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
        ],
      ),
    );
  }
}

/// "Routine on track · 2 of 4 study blocks done today". Only shown when there
/// are study blocks to be on track against.
class _RoutineOnTrack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final blocks = context
        .watch<RoutineProvider>()
        .blocksFor(now)
        .where((b) => b.type.canFocus)
        .toList();
    if (blocks.isEmpty) return const SizedBox.shrink();

    // blocks is non-empty here, so adherence is never null.
    final adherence =
        context.watch<FocusProvider>().adherenceFor(blocks, now) ?? 0;
    final done = (adherence * blocks.length).round();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.gapTight),
      child: WakeCard(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.done.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(Icons.science_outlined, size: 18, color: c.done),
            ),
            const SizedBox(width: AppSpacing.gapTight),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Routine on track',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('$done of ${blocks.length} study blocks done today',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return WakeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: numberStyle(fontSize: 24, color: color)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Design 4k's "what pulled at you". Only rendered when the shield actually
/// ran -- the counts are measured, never estimated.
class _PulledAtYou extends StatelessWidget {
  final Map<String, int> opens;
  const _PulledAtYou({required this.opens});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final sorted = opens.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    final max = top.first.value;
    final total = opens.values.fold<int>(0, (a, b) => a + b);

    return WakeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT PULLED AT YOU', style: sectionLabelStyle(c.textMuted)),
          const SizedBox(height: AppSpacing.gapTight),
          for (final e in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      e.key,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 6,
                        backgroundColor: c.divider,
                        valueColor: AlwaysStoppedAnimation(c.accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapTight),
                  Text('${e.value}',
                      style: numberStyle(fontSize: 15, color: c.textPrimary)),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            total == 1
                ? 'Blocked once. That is one pull you did not follow.'
                : 'Blocked $total times. Those are pulls you did not follow.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
