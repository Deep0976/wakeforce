import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/routine_block.dart';
import '../services/routine_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';
import 'block_editor_screen.dart';
import 'focus_setup_screen.dart';

/// The Routine timeline, shown as the second view inside Alarms rather than
/// a tab of its own.
class RoutineView extends StatefulWidget {
  const RoutineView({super.key});

  @override
  State<RoutineView> createState() => _RoutineViewState();
}

class _RoutineViewState extends State<RoutineView> {
  Timer? _tick;
  DateTime _now = DateTime.now();

  /// Which day the timeline is showing. Defaults to today; the week strip
  /// lets the student look ahead without editing anything.
  int _dayOffset = 0;

  DateTime get _shownDay =>
      DateTime(_now.year, _now.month, _now.day).add(Duration(days: _dayOffset));

  bool get _isToday => _dayOffset == 0;

  @override
  void initState() {
    super.initState();
    // The active block shows minutes remaining, so the view has to move on
    // its own rather than only when the list changes.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _durationLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static const _weekdayNames = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final routine = context.watch<RoutineProvider>();
    final blocks = routine.blocksFor(_shownDay);
    final planned = routine.plannedMinutesFor(_shownDay);

    final weekStrip = _WeekStrip(
      now: _now,
      selectedOffset: _dayOffset,
      countFor: (day) => routine.blocksFor(day).length,
      onSelect: (offset) => setState(() => _dayOffset = offset),
    );

    if (blocks.isEmpty) {
      // Zero state says what to do next rather than showing 0 in every tile.
      return Column(
        children: [
          weekStrip,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 44,
                      color: c.textFaint,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    Text(
                      _isToday ? 'No blocks for today' : 'Nothing planned',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Plan your day in blocks — study, breaks and everything else.\nTap + to add the first one.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        weekStrip,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.xs,
              AppSpacing.screen,
              96,
            ),
            children: [
              Text(
                '${_weekdayNames[_shownDay.weekday - 1]} · ${_durationLabel(planned)} PLANNED',
                style: sectionLabelStyle(c.textMuted),
              ),
              const SizedBox(height: AppSpacing.gap),
              for (final block in blocks)
                _BlockRow(
                  block: block,
                  now: _now,
                  onEdit: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlockEditorScreen(block: block),
                    ),
                  ),
                  onFocus: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FocusSetupScreen(
                        initialSubject: block.title,
                        block: block,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seven-day strip so the routine can be read a week ahead, per the design's
/// "Week view" control.
class _WeekStrip extends StatelessWidget {
  final DateTime now;
  final int selectedOffset;
  final int Function(DateTime day) countFor;
  final ValueChanged<int> onSelect;

  const _WeekStrip({
    required this.now,
    required this.selectedOffset,
    required this.countFor,
    required this.onSelect,
  });

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        AppSpacing.gapTight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (context) {
                final day = today.add(Duration(days: i));
                final selected = selectedOffset == i;
                final has = countFor(day) > 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? c.accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                        color: selected ? c.accent : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _initials[day.weekday - 1],
                          style: sectionLabelStyle(
                            selected ? c.accentInk : c.textMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: numberStyle(
                            fontSize: 13,
                            color: selected ? c.accentInk : c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // A dot means the day has something planned, so the
                        // strip is scannable without opening each day.
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: has ? c.accent : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  final RoutineBlock block;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onFocus;

  const _BlockRow({
    required this.block,
    required this.now,
    required this.onEdit,
    required this.onFocus,
  });

  Color _railColor(WakeColors c) {
    switch (block.type) {
      case BlockType.study:
        return c.accent;
      case BlockType.breakTime:
        return c.done;
      case BlockType.personal:
        return c.personal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    final rail = _railColor(c);
    final isActive = block.isActiveAt(now);
    final remaining = block.minutesRemainingAt(now);
    final progress = isActive && block.durationMinutes > 0
        ? 1 - (remaining / block.durationMinutes)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gapTight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time gutter.
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.cardTight),
              child: Text(
                RoutineBlock.formatMinute(block.startMinute),
                style: numberStyle(
                  fontSize: 12,
                  color: c.textMuted,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Expanded(
            child: WakeCard(
              tint: isActive ? rail : null,
              padding: EdgeInsets.zero,
              // The rail is a left border rather than a stretched sibling in
              // an IntrinsicHeight row: intrinsic sizing hands its children
              // unbounded width, which the buttons below cannot lay out
              // against and which took the whole row down with it.
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: rail, width: 3)),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.cardTight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              block.title,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive)
                            Text(
                              'NOW · ${remaining}M LEFT',
                              style: sectionLabelStyle(rail),
                            )
                          else if (block.ringAsAlarm)
                            Text('ALARM', style: sectionLabelStyle(c.textFaint))
                          else
                            Text(
                              'ALERT',
                              style: sectionLabelStyle(c.textFaint),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(_subtitle(), style: theme.textTheme.bodySmall),
                      if (isActive) ...[
                        const SizedBox(height: AppSpacing.gapTight),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: c.divider,
                            valueColor: AlwaysStoppedAnimation(rail),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.gapTight),
                      Row(
                        children: [
                          // Height comes from the button's own
                          // minimumSize, not a SizedBox: a tight-height
                          // box around a Material button that is the
                          // only non-flex child of a Row hands it
                          // unbounded width and fails to lay out.
                          if (isActive && block.type.canFocus) ...[
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: onFocus,
                                child: const Text('Start Focus'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                          ],
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                            ),
                            onPressed: onEdit,
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[block.timeRangeLabel, block.type.label];
    if (block.ringAsAlarm) {
      parts.add('rings');
    } else if (block.remindBeforeMinutes > 0) {
      parts.add('alert ${block.remindBeforeMinutes}m early');
    } else {
      parts.add('alert at start');
    }
    return parts.join(' · ');
  }
}
