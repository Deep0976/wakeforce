import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/routine_block.dart';
import '../services/routine_provider.dart';
import '../theme/app_theme.dart';
import '../utils/day_labels.dart';
import '../widgets/time_wheel.dart';
import '../widgets/wake_card.dart';

/// Create or edit one routine block. Pushed from the Routine view, never a
/// tab of its own.
class BlockEditorScreen extends StatefulWidget {
  final RoutineBlock? block;

  const BlockEditorScreen({super.key, this.block});

  bool get isEditing => block != null;

  @override
  State<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends State<BlockEditorScreen> {
  late TextEditingController _title;
  late int _start;
  late int _end;
  late Set<int> _days;
  late BlockType _type;
  late int _remindBefore;
  late bool _ringAsAlarm;
  late bool _startsFocus;

  /// The design offers these as one-tap starting points above the field.
  static const _quickTitles = ['Physics', 'Chemistry', 'Maths', 'Lunch', 'Gym'];

  @override
  void initState() {
    super.initState();
    final b = widget.block;
    _title = TextEditingController(text: b?.title ?? '');
    // A new block starts from where the student actually is, rounded up to
    // the next 15 minutes -- the old fixed 08:00-10:00 meant every block had
    // to be dragged a long way before it meant anything.
    final now = DateTime.now();
    final rounded = ((now.hour * 60 + now.minute + 14) ~/ 15) * 15;
    _start = b?.startMinute ?? (rounded % (24 * 60));
    // Clamp rather than wrap: (start + 60) % 1440 puts a late-evening block's
    // end BEFORE its start, which is not a block at all.
    _end = b?.endMinute ?? (_start + 60 >= 24 * 60 ? 24 * 60 - 1 : _start + 60);
    // Defaults to today, not Mon-Fri. A weekdays default means a block
    // created at the weekend saves correctly and then does not appear,
    // because the timeline shows today -- it looks exactly like it failed
    // to save.
    _days = {...(b?.days ?? {now.weekday})};
    _type = b?.type ?? BlockType.study;
    _remindBefore = b?.remindBeforeMinutes ?? 0;
    _ringAsAlarm = b?.ringAsAlarm ?? false;
    _startsFocus = b?.startsFocus ?? false;
  }

  /// Exposed for tests: the repeat days a freshly-opened editor starts with.
  @visibleForTesting
  Set<int> get testDays => _days;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    // The same scroll wheel as the alarm screen: setting a block should not
    // be harder than setting an alarm.
    final value = await pickTimeWheel(
      context,
      initialMinutes: isStart ? _start : _end,
      title: isStart ? 'BLOCK STARTS' : 'BLOCK ENDS',
    );
    if (value == null) return;
    setState(() {
      if (isStart) {
        _start = value;
        // Keep the block at least 15 minutes long rather than letting the
        // end slide behind the start.
        if (_end <= _start) _end = (_start + 15).clamp(0, 24 * 60);
      } else {
        _end = value <= _start ? (_start + 15).clamp(0, 24 * 60) : value;
      }
    });
  }

  Future<void> _save() async {
    final routine = context.read<RoutineProvider>();
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the block a name first')),
      );
      return;
    }
    final block = RoutineBlock(
        id: widget.block?.id ?? routine.newId(),
        title: title,
        startMinute: _start,
        endMinute: _end,
        days: _days,
        type: _type,
        remindBeforeMinutes: _remindBefore,
        ringAsAlarm: _ringAsAlarm,
        // Only study blocks can open a Focus session, so don't persist a
        // stale true if the type was switched after the toggle was set.
        startsFocus: _type.canFocus && _startsFocus,
    );
    await routine.upsert(block);
    if (!mounted) return;
    _confirmWhenItFires(block);
    Navigator.of(context).pop();
  }

  /// Always says when the block will next actually fire.
  ///
  /// Scheduling silently was the real bug behind "I set lunch for 12:30 and it
  /// never rang": the block was saved for 00:30, that time had already gone,
  /// and it rolled to the same day next week without a word. An AM/PM slip is
  /// easy to make at half past midnight -- it should not cost a week.
  void _confirmWhenItFires(RoutineBlock block) {
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved, but no repeat days are picked, so it will '
              'never fire.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final fire = block.nextFireTime(from: now);
    final today = DateTime(now.year, now.month, now.day);
    final fireDay = DateTime(fire.year, fire.month, fire.day);
    final daysAway = fireDay.difference(today).inDays;

    final clock = TimeOfDay.fromDateTime(fire).format(context);
    final String when;
    if (daysAway == 0) {
      when = 'today at $clock';
    } else if (daysAway == 1) {
      when = 'tomorrow at $clock';
    } else {
      when = '${weekdayShortLabels[fire.weekday - 1]} '
          '${fire.day}/${fire.month} at $clock';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // A week away is almost always a mistake, so hold it on screen.
        duration: Duration(seconds: daysAway > 1 ? 8 : 4),
        content: Text(
          daysAway > 1
              ? 'Saved — but the next reminder is not until $when. '
                  'Check AM/PM and the repeat days.'
              : 'Saved. Next reminder $when.',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (widget.block == null) return;
    await context.read<RoutineProvider>().delete(widget.block!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit block' : 'New block'),
        actions: [
          if (widget.isEditing)
            TextButton(
              onPressed: _delete,
              child: Text(
                'DELETE',
                style: sectionLabelStyle(const Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.gap,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          // Start / end.
          WakeCard(
            child: Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'START',
                    value: RoutineBlock.formatMinute(_start),
                    onTap: () => _pickTime(isStart: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text('—', style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: _TimeField(
                    label: 'END',
                    value: RoutineBlock.formatMinute(_end),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    _durationLabel(_end - _start),
                    style: numberStyle(fontSize: 11, color: c.accentInk)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapWide),

          SectionLabel('What is this block?'),
          WakeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _title,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: 'Physics — rotational motion',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: theme.textTheme.bodyMedium
                        ?.copyWith(color: c.textFaint),
                  ),
                ),
                const SizedBox(height: AppSpacing.gapTight),
                // Five real words: sharing the width would ellipsise
                // "Chemistry" down to a stub, so the line scrolls instead of
                // squashing or wrapping.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in _quickTitles)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: _Chip(
                            label: t,
                            selected: false,
                            onTap: () => setState(() {
                              _title.text = t;
                              _title.selection = TextSelection.fromPosition(
                                TextPosition(offset: t.length),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.gap),
                // One line. Expanded rather than intrinsic widths so the
                // chips divide the row and can never overflow it.
                Row(
                  children: [
                    for (final type in BlockType.values) ...[
                      Expanded(
                        child: _Chip(
                          label: type.label,
                          selected: _type == type,
                          compact: true,
                          onTap: () => setState(() => _type = type),
                        ),
                      ),
                      if (type != BlockType.values.last)
                        const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapWide),

          SectionLabel('Repeat'),
          WakeCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _DayPill(
                        label: weekdayShortLabels[i][0],
                        selected: _days.contains(i + 1),
                        onTap: () => setState(() {
                          final day = i + 1;
                          _days.contains(day)
                              ? _days.remove(day)
                              : _days.add(day);
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapWide),

          SectionLabel('Remind me before'),
          WakeCard(
            child: Column(
              children: [
                Row(
                  children: [
                    for (final m in const [0, 5, 10, 15]) ...[
                      Expanded(
                        child: _Chip(
                          label: m == 0 ? 'At start' : '${m}m',
                          selected: _remindBefore == m,
                          compact: true,
                          onTap: () => setState(() => _remindBefore = m),
                        ),
                      ),
                      if (m != 15) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _ToggleRow(
                  label: 'Ring as full alarm',
                  value: _ringAsAlarm,
                  onChanged: (v) => setState(() => _ringAsAlarm = v),
                ),
                _ToggleRow(
                  label: 'Start Focus · study only',
                  value: _startsFocus && _type.canFocus,
                  // Greyed out on break/personal blocks, matching the design's
                  // "study only" qualifier.
                  onChanged: _type.canFocus
                      ? (v) => setState(() => _startsFocus = v)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save block'),
            ),
          ),
        ],
      ),
    );
  }

  static String _durationLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.control),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: numberStyle(fontSize: 26, color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: sectionLabelStyle(c.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tighter side padding for chips that share a divided row instead of
  /// sizing to their own text.
  final bool compact;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.16) : c.bg,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? c.accent : c.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? c.accentInk : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayPill({
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
        // No fixed width: seven 38px pills need 266px, which does not fit
        // inside the card on a 320dp screen. They divide the row instead.
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.16) : c.bg,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? c.accent : c.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? c.accentInk : c.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final enabled = onChanged != null;
    return SizedBox(
      height: kMinHitTarget,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled ? c.textSecondary : c.textFaint,
                  ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
