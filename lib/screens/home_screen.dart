import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mission_type.dart';
import '../models/routine_block.dart';
import '../services/alarm_provider.dart';
import '../services/auth_service.dart';
import '../services/stats_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_tile.dart';
import '../widgets/subject_icon.dart';
import '../widgets/wake_card.dart';
import 'alarms_screen.dart';
import '../services/routine_provider.dart';
import 'edit_alarm_screen.dart';
import 'focus_setup_screen.dart';
import 'ringing_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  String _remainingLabel(DateTime next) {
    final diff = next.difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'Ringing soon';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    parts.add('${minutes}m');
    return '${parts.join(' ')} remaining';
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);

    return Consumer<AlarmProvider>(
      builder: (context, provider, _) {
        final alarms = provider.alarms.where((a) => a.enabled).toList()
          ..sort((a, b) => a.nextOccurrence().compareTo(b.nextOccurrence()));
        final next = provider.nextAlarm;
        final user = context.watch<AuthService>().currentUser;
        final streak = context.watch<StatsProvider>().stats.currentStreak;

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
                  children: [
                    _Wordmark(),
                    _StreakPill(streak: streak),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapWide),
                Text(_greeting(), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  user?.displayName ?? 'there',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Discipline today, success tomorrow.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.gapWide),
                if (next != null)
                  _NextMissionCard(
                    timeLabel: next.timeLabel,
                    isToday: _isToday(next.nextOccurrence()),
                    remaining: _remainingLabel(next.nextOccurrence()),
                    missionLabel: next.missionType.label,
                    difficulty: next.difficulty.name,
                    accent: next.missionType.accentColor(c),
                    missionType: next.missionType,
                  )
                else
                  const _NoAlarmCard(),
                const SizedBox(height: AppSpacing.gapTight),
                // Quick actions: Focus is entered from here as well as the
                // tab bar, and the routine card jumps into today's plan.
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.notifications_off_outlined,
                        title: 'Start Focus',
                        subtitle: 'Silence everything',
                        tint: c.accent,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FocusSetupScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.gapTight),
                    Expanded(
                      child: Builder(builder: (context) {
                        final routine = context.watch<RoutineProvider>();
                        final now = DateTime.now();
                        final active = routine.activeBlockAt(now);
                        final upcoming = routine.nextBlockAfter(now);
                        final block = active ?? upcoming;
                        return _QuickAction(
                          icon: Icons.calendar_month_outlined,
                          title: "Today's routine",
                          subtitle: block == null
                              ? 'Plan your day'
                              : '${block.title} at '
                                  '${RoutineBlock.formatMinute(block.startMinute)}',
                          tint: c.personal,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AlarmsScreen(startOnRoutine: true),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapWide),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Upcoming alarms', style: theme.textTheme.titleMedium),
                    if (alarms.isNotEmpty)
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AlarmsScreen(),
                          ),
                        ),
                        child: Text(
                          'See all',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.accentInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapTight),
                if (alarms.isEmpty)
                  const _EmptyUpcoming()
                else
                  ...alarms.take(3).map(
                        (alarm) => AlarmTile(
                          alarm: alarm,
                          onToggle: (value) =>
                              provider.toggleAlarm(alarm.id, value),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditAlarmScreen(alarm: alarm),
                            ),
                          ),
                          onTestRing: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RingingScreen(alarm: alarm),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.headlineSmall,
        children: [
          TextSpan(text: 'Wake', style: TextStyle(color: c.textPrimary)),
          TextSpan(text: 'Force', style: TextStyle(color: c.accent)),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: c.cardBorder == null ? null : Border.all(color: c.cardBorder!),
        boxShadow: c.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, size: 15, color: c.accent),
          const SizedBox(width: 6),
          Text('$streak', style: numberStyle(fontSize: 14, color: c.textPrimary)),
          const SizedBox(width: 4),
          Text(
            'Day Streak',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// The hero. Everything stacks in one vertical rhythm: label, time, when,
/// mission chip, countdown -- rather than spreading across the card.
class _NextMissionCard extends StatelessWidget {
  final String timeLabel;
  final bool isToday;
  final String remaining;
  final String missionLabel;
  final String difficulty;
  final Color accent;
  final MissionType missionType;

  const _NextMissionCard({
    required this.timeLabel,
    required this.isToday,
    required this.remaining,
    required this.missionLabel,
    required this.difficulty,
    required this.accent,
    required this.missionType,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final capitalisedDifficulty =
        difficulty[0].toUpperCase() + difficulty.substring(1);

    return WakeCard(
      tint: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT MISSION', style: sectionLabelStyle(c.textMuted)),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      timeLabel,
                      style: numberStyle(fontSize: 30, color: c.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${isToday ? 'Today' : 'Tomorrow'} · $remaining',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.gapTight),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    '$missionLabel · $capitalisedDifficulty',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.gap),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            alignment: Alignment.center,
            child: missionGlyph(missionType, size: 20, color: accent),
          ),
        ],
      ),
    );
  }
}

/// Zero state that says what to do next rather than showing an empty card.
class _NoAlarmCard extends StatelessWidget {
  const _NoAlarmCard();

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    return WakeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT MISSION', style: sectionLabelStyle(c.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text('No alarm set', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Set one in Alarms and pick the mission that wakes you properly.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return WakeCard(
      child: Text(
        'Nothing scheduled. Add an alarm to start a streak.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}


/// One of the two square shortcuts under the next-mission card.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WakeCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.cardTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Icon(icon, size: 17, color: tint),
          ),
          const SizedBox(height: AppSpacing.gapTight),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
