import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/focus_provider.dart';
import '../services/routine_provider.dart';
import '../services/stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final statsProvider = context.watch<StatsProvider>();
    final stats = statsProvider.stats;
    final focus = context.watch<FocusProvider>();
    final routine = context.watch<RoutineProvider>();

    final adherence =
        focus.adherenceFor(routine.blocksFor(DateTime.now()), DateTime.now());

    final questionsSolved =
        stats.mathSolved + stats.physicsSolved + stats.chemistrySolved;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.gap,
            AppSpacing.screen,
            AppSpacing.lg,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Progress', style: theme.textTheme.headlineSmall),
                Text(
                  'This week',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: c.accentInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapWide),

            // Streak + level, the headline card.
            WakeCard(
              tint: c.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current streak',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${stats.currentStreak}',
                                  style: numberStyle(
                                    fontSize: 30,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  stats.currentStreak == 1 ? 'day' : 'days',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'best ${stats.bestStreak}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.local_fire_department,
                        color: c.accent,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  Divider(height: 1, color: c.divider),
                  const SizedBox(height: AppSpacing.gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible: a long level title next to the XP counter
                      // overflowed the card once the numbers grew past a
                      // couple of digits.
                      Flexible(
                        child: Text(
                          'Level ${statsProvider.level} · ${statsProvider.levelTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.titleMedium?.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${statsProvider.xpIntoLevel} / ${statsProvider.xpPerLevel} XP',
                        style: numberStyle(fontSize: 11, color: c.textMuted)
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: statsProvider.xpPerLevel == 0
                          ? 0
                          : statsProvider.xpIntoLevel / statsProvider.xpPerLevel,
                      minHeight: 6,
                      backgroundColor: c.divider,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapWide),

            // Per-subject counts.
            WakeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    'Questions solved',
                    trailing: Text('all time', style: theme.textTheme.bodySmall),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SubjectStat(
                        value: stats.mathSolved,
                        label: 'Maths',
                        color: c.accent,
                        total: questionsSolved,
                      ),
                      _SubjectStat(
                        value: stats.chemistrySolved,
                        label: 'Chemistry',
                        color: c.done,
                        total: questionsSolved,
                      ),
                      _SubjectStat(
                        value: stats.physicsSolved,
                        label: 'Physics',
                        color: c.physics,
                        total: questionsSolved,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  Divider(height: 1, color: c.divider),
                  const SizedBox(height: AppSpacing.gap),
                  _WeeklyLine(
                    completed: stats.alarmsCompletedThisWeek,
                    rate: statsProvider.successRateThisWeek,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapWide),

            // Focus and routine, aggregated alongside alarm missions.
            WakeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                    'Focus & routine',
                    trailing: Text(
                      _focusDelta(focus),
                      style: theme.textTheme.bodySmall?.copyWith(color: c.done),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Per the design: a zero state says what to do next rather
                  // than showing 0 in every tile. Three zeros read as "this
                  // feature is broken" when it just hasn't been used yet.
                  if (focus.sessions.isEmpty)
                    Text(
                      'No focus sessions yet. Start one from Home or a study '
                      'block and your hours, time on task and adherence show '
                      'up here.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniStat(
                          value: _hours(focus.focusMinutesThisWeek),
                          label: 'focused',
                        ),
                        _MiniStat(
                          // Em dash, not 0%: no goal session sat yet means
                          // there is nothing to score, not a failure.
                          value: focus.timeOnTask == null
                              ? '—'
                              : '${(focus.timeOnTask! * 100).round()}%',
                          label: 'on task',
                        ),
                        _MiniStat(
                          // Em dash when no study blocks are planned: you
                          // cannot fail to adhere to a routine you have not
                          // made.
                          value: adherence == null
                              ? '—'
                              : '${(adherence * 100).round()}%',
                          label: 'adherence',
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.gapWide),

            WakeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('This week'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _MiniStat(
                        value: '${stats.alarmsCompletedThisWeek}',
                        label: 'alarms solved',
                      ),
                      _MiniStat(
                        // An em dash, not 0% and not 100%: nothing rang, so
                        // there is nothing to be successful at.
                        value: statsProvider.successRateThisWeek == null
                            ? '—'
                            : '${(statsProvider.successRateThisWeek! * 100).round()}%',
                        label: 'success rate',
                      ),
                      _MiniStat(
                        value: '${stats.alarmsAttemptedThisWeek}',
                        label: 'alarms rang',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final int total;

  const _SubjectStat({
    required this.value,
    required this.label,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: numberStyle(fontSize: 22, color: c.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.gap),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (value / total).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: c.divider,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyLine extends StatelessWidget {
  final int completed;

  /// Null when no alarm has rung this week -- there is no rate to report.
  final double? rate;

  const _WeeklyLine({required this.completed, required this.rate});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    if (completed == 0) {
      return Text(
        'No alarms solved yet this week. Solve one to start the count.',
        style: theme.textTheme.bodySmall,
      );
    }
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall,
        children: rate == null
            ? [const TextSpan(text: 'No alarms have rung this week yet.')]
            : [
                TextSpan(text: '$completed alarms solved this week · '),
                TextSpan(
                  text: '${(rate! * 100).round()}%',
                  style: TextStyle(color: c.done, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' success rate'),
              ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: numberStyle(fontSize: 20, color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}


String _hours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String _focusDelta(FocusProvider focus) {
  final thisWeek = focus.focusMinutesThisWeek;
  final delta = thisWeek - focus.focusMinutesLastWeek;
  // Nothing either week is not "the same as last week" -- that phrasing, in
  // green, reads as holding steady when in fact no focus has ever happened.
  if (thisWeek == 0 && focus.focusMinutesLastWeek == 0) return '';
  if (delta == 0) return 'same as last week';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${_hours(delta.abs())} vs last week';
}
