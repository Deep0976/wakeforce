import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm.dart';
import '../models/mission_type.dart';
import '../models/routine_block.dart';
import '../services/routine_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_ui.dart';
import '../widgets/wake_card.dart';
import 'focus_setup_screen.dart';

class MissionCompleteScreen extends StatelessWidget {
  final int xpEarned;
  final int currentStreak;

  /// The mission just solved. Carried only so a feedback answer given here
  /// arrives with the thing it is about -- two stars on an Advanced physics
  /// question means something different from two stars on Easy maths.
  final MissionType missionType;
  final MissionDifficulty difficulty;

  const MissionCompleteScreen({
    super.key,
    required this.xpEarned,
    required this.currentStreak,
    required this.missionType,
    required this.difficulty,
  });

  static const _quotes = [
    'The secret of getting ahead is getting started.',
    'Discipline is choosing between what you want now and what you want most.',
    'Small steps every morning build unstoppable momentum.',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final quote = _quotes[Random().nextInt(_quotes.length)];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.emoji_events, size: 38, color: c.accent),
              ),
              const SizedBox(height: AppSpacing.gapWide),
              Text('Mission complete', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Great start to your day.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),

              // Lead with what was earned.
              Row(
                children: [
                  Expanded(
                    child: _ResultTile(
                      value: '+$xpEarned',
                      unit: 'XP',
                      label: 'earned',
                      color: c.done,
                      icon: Icons.bolt,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gapTight),
                  Expanded(
                    child: _ResultTile(
                      value: '$currentStreak',
                      unit: currentStreak == 1 ? 'day' : 'days',
                      label: 'streak',
                      color: c.accent,
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapWide),
              WakeCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: c.textFaint,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(quote, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  // Leaving the celebration is the moment to ask: the alarm
                  // that is being rated just happened, and the shell below is
                  // about to be the top route, so the prompt is not stacked
                  // over this screen.
                  final navigator = Navigator.of(context);
                  navigator.popUntil((route) => route.isFirst);
                  maybeAskAfterMission(
                    navigator.context,
                    answerContext: {
                      'mission': missionType.name,
                      'difficulty': difficulty.name,
                    },
                  );
                },
                child: const Text('Continue'),
              ),
              // Hands off to the next thing rather than dead-ending: if a
              // study block is coming up, offer to sit down for it now.
              Builder(
                builder: (context) {
                  final next = context.read<RoutineProvider>().nextBlockAfter(
                    DateTime.now(),
                  );
                  if (next == null || !next.type.canFocus) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FocusSetupScreen(
                              initialSubject: next.title,
                              block: next,
                            ),
                          ),
                        );
                      },
                      child: Text('Start ${next.title} focus instead'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  final IconData icon;

  const _ResultTile({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WakeCard(
      tint: color,
      padding: const EdgeInsets.all(AppSpacing.cardTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: numberStyle(fontSize: 24, color: color)),
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
