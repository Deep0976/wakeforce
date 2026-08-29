import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The hour : minute : AM/PM scroll wheel used to set an alarm. Routine
/// blocks use the same one so setting a block feels no harder than setting
/// an alarm -- there is one time picker in this app, not two.
class TimeWheel extends StatefulWidget {
  /// Minutes since midnight.
  final int initialMinutes;
  final ValueChanged<int> onChanged;

  const TimeWheel({
    super.key,
    required this.initialMinutes,
    required this.onChanged,
  });

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late final FixedExtentScrollController _hour;
  late final FixedExtentScrollController _minute;
  late final FixedExtentScrollController _period;

  @override
  void initState() {
    super.initState();
    final h24 = widget.initialMinutes ~/ 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    _hour = FixedExtentScrollController(initialItem: h12 - 1);
    _minute = FixedExtentScrollController(initialItem: widget.initialMinutes % 60);
    _period = FixedExtentScrollController(initialItem: h24 < 12 ? 0 : 1);
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    _period.dispose();
    super.dispose();
  }

  void _emit() {
    // A looping wheel's selectedItem is the RAW scroll index: it goes
    // negative scrolling up and past the end scrolling down. Taken straight
    // it would produce hour 0 or hour 16. Dart's % is non-negative for a
    // positive divisor, so this folds it back into range either way.
    final h12 = (_hour.selectedItem % 12) + 1;
    final minute = _minute.selectedItem % 60;
    final isPm = _period.selectedItem == 1;
    final h24 = switch ((h12, isPm)) {
      (12, false) => 0,
      (12, true) => 12,
      (_, true) => h12 + 12,
      (_, false) => h12,
    };
    widget.onChanged(h24 * 60 + minute);
  }

  Widget _wheel(
    FixedExtentScrollController controller,
    List<String> values, {
    bool loop = false,
  }) {
    final c = context.wake;
    return SizedBox(
      width: 68,
      height: 150,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 38,
        squeeze: 1.1,
        // Hours and minutes wrap round, so 12 rolls straight back to 01 and
        // 59 to 00 instead of hitting a wall. AM/PM is left unlooped: two
        // items spinning forever is disorienting, and both are one flick away.
        looping: loop,
        onSelectedItemChanged: (_) => _emit(),
        selectionOverlay: Container(
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ),
        children: values
            .map((v) => Center(
                  child: Text(
                    v,
                    style: numberStyle(fontSize: 20, color: c.textPrimary),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _wheel(_hour, List.generate(12, (i) => '${i + 1}'.padLeft(2, '0')),
            loop: true),
        Text(':', style: numberStyle(fontSize: 22, color: c.textMuted)),
        _wheel(_minute, List.generate(60, (i) => '$i'.padLeft(2, '0')),
            loop: true),
        const SizedBox(width: AppSpacing.xs),
        _wheel(_period, const ['AM', 'PM']),
      ],
    );
  }
}

/// Bottom-sheet wrapper around [TimeWheel]. Returns minutes since midnight,
/// or null if dismissed.
Future<int?> pickTimeWheel(
  BuildContext context, {
  required int initialMinutes,
  required String title,
}) {
  var value = initialMinutes;
  return showModalBottomSheet<int>(
    context: context,
    builder: (sheetContext) {
      final c = sheetContext.wake;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: sectionLabelStyle(c.textMuted)),
              const SizedBox(height: AppSpacing.gap),
              TimeWheel(
                initialMinutes: initialMinutes,
                onChanged: (v) => value = v,
              ),
              const SizedBox(height: AppSpacing.gap),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(value),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
