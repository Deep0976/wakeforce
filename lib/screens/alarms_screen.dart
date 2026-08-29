import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/alarm_provider.dart';
import '../services/focus_dnd_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_tile.dart';
import '../widgets/wake_card.dart';
import 'block_editor_screen.dart';
import 'edit_alarm_screen.dart';
import 'ringing_screen.dart';
import 'routine_view.dart';

/// Holds two views: Wake alarms and Routine. New alarm and Block editor are
/// pushed screens off it, never tabs.
class AlarmsScreen extends StatefulWidget {
  /// Opens straight onto the Routine timeline -- Home's routine card lands
  /// here and would otherwise dump the student on Wake alarms.
  final bool startOnRoutine;

  const AlarmsScreen({super.key, this.startOnRoutine = false});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen>
    with WidgetsBindingObserver {
  /// Android 14+ silently downgrades a full-screen alarm to a heads-up
  /// notification unless the student allows it. An alarm that needs tapping
  /// is not an alarm, so this is worth a banner rather than a settings row.
  bool _canFullScreen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFullScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkFullScreen();
  }

  Future<void> _checkFullScreen() async {
    final ok = await FocusDndService.instance.canFullScreen();
    if (mounted) setState(() => _canFullScreen = ok);
  }

  late bool _showRoutine = widget.startOnRoutine;

  void _add() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _showRoutine ? const BlockEditorScreen() : const EditAlarmScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AlarmProvider>(
      builder: (context, provider, _) {
        final alarms = [...provider.alarms]
          ..sort((a, b) => a.nextOccurrence().compareTo(b.nextOccurrence()));

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.gap,
                    AppSpacing.screen,
                    AppSpacing.gapTight,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Alarms', style: theme.textTheme.headlineSmall),
                    ],
                  ),
                ),
                if (!_canFullScreen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      AppSpacing.gapTight,
                    ),
                    child: WakeCard(
                      tint: context.wake.accent,
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 20, color: context.wake.accentInk),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Alarms will not open on their own. Allow '
                              'full-screen notifications so they ring on '
                              'screen instead of waiting to be tapped.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: FocusDndService.instance.requestFullScreen,
                            child: Text('ALLOW',
                                style: sectionLabelStyle(context.wake.accentInk)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.gap,
                  ),
                  child: Row(
                    children: [
                      _ViewTab(
                        label: 'Wake alarms',
                        selected: !_showRoutine,
                        onTap: () => setState(() => _showRoutine = false),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ViewTab(
                        label: 'Routine',
                        selected: _showRoutine,
                        onTap: () => setState(() => _showRoutine = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _showRoutine
                      ? const RoutineView()
                      : alarms.isEmpty
                      ? const _EmptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screen,
                            0,
                            AppSpacing.screen,
                            96,
                          ),
                          children: [
                            ...alarms.map(
                              (alarm) => AlarmTile(
                                alarm: alarm,
                                onToggle: (value) =>
                                    provider.toggleAlarm(alarm.id, value),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditAlarmScreen(alarm: alarm),
                                  ),
                                ),
                                onTestRing: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RingingScreen(alarm: alarm),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.gapTight),
                            _AlarmCount(count: alarms.length),
                          ],
                        ),
                ),
              ],
            ),
          ),
          // One add button, bottom-right, on both views. It used to sit in
          // the header on Routine so it could not cover a timeline row, but
          // two different positions for the same action is worse than the
          // overlap -- the list already reserves bottom padding for it.
          floatingActionButton: FloatingActionButton(
            onPressed: _add,
            child: const Icon(Icons.add, size: 26),
          ),
        );
      },
    );
  }
}

class _AlarmCount extends StatelessWidget {
  final int count;
  const _AlarmCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return WakeCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.card,
        vertical: AppSpacing.cardTight,
      ),
      child: Column(
        children: [
          Text(
            '$count of $kFreeAlarmSlots free alarm slots used',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            "Routine blocks don't count against this.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_add_outlined, size: 44, color: c.textMuted),
            const SizedBox(height: AppSpacing.gap),
            Text('No alarms yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tap + to set your first one and pick the mission\nthat has to be solved before it stops.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// How many wake alarms the free tier allows, per the design's
/// "3 of 5 free alarm slots used" line.
const int kFreeAlarmSlots = 5;

/// Segmented control for the two views inside Alarms.
class _ViewTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.16) : c.card,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? c.accent : (c.cardBorder ?? c.divider),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? c.accentInk : c.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
