import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// The reported bug: "the maths question and 4 options came in dark mode".
///
/// The ringing panel (4m) is dark by design, but the mission screen (4d) is a
/// light screen. Wrapping the whole RingingScreen in the dark theme dragged
/// the question into dark mode with it. RingingScreen itself needs audio and
/// wakelock plugins to build, so this pins the property that actually broke:
/// the two palettes must be distinguishable, and a screen that opts into dark
/// must not leak it to a sibling that did not.
void main() {
  testWidgets('a scoped dark Theme does not leak to its siblings',
      (tester) async {
    late WakeColors insideDark;
    late WakeColors outsideDark;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildWakeForceLightTheme(),
        home: Column(
          children: [
            // The ringing panel: explicitly dark.
            Theme(
              data: buildWakeForceDarkTheme(),
              child: Builder(builder: (c) {
                insideDark = c.wake;
                return const SizedBox.shrink();
              }),
            ),
            // The mission: must stay on the app theme.
            Builder(builder: (c) {
              outsideDark = c.wake;
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );

    expect(insideDark.bg, isNot(equals(outsideDark.bg)),
        reason: 'dark and light backgrounds must actually differ');
    expect(outsideDark.bg, WakeColors.light.bg,
        reason: 'the mission screen must stay on the light palette');
    expect(insideDark.bg, WakeColors.dark.bg);
  });
}
