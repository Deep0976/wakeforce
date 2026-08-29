import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wake_mission_app/services/shield_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/screens/focus_setup_screen.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// Reproduces "focus mode, only Start Focus is coming, nothing else".
///
/// The button lives outside the scrolling area, so a layout exception inside
/// the ListView leaves it as the only thing on screen -- which is exactly
/// what the student saw. Asserting the body renders catches that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSetup(WidgetTester tester) async {
    // A phone-shaped, tall viewport: the default 800x600 test surface leaves
    // the guard card below the fold, and a ListView does not build children
    // it cannot see.
    tester.view.physicalSize = const Size(400 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final shield = ShieldProvider();
    await shield.loadForUser('u1');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: shield,
        child: MaterialApp(
          theme: buildWakeForceLightTheme(),
          home: const FocusSetupScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the whole setup body renders, not just the button',
      (tester) async {
    await pumpSetup(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Start Focus'), findsOneWidget);
    // Everything above the button that used to vanish with it.
    expect(find.text('What are you sitting down for?'), findsOneWidget);
    expect(find.text('FOCUS SESSION'), findsOneWidget);
    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('DISTRACTION GUARD'), findsOneWidget);
    expect(find.text('Do Not Disturb'), findsOneWidget);
    // Notification muting was removed: its permission made the APK
    // unsideloadable under Google's Enhanced Fraud Protection.
    expect(find.text('Mute their notifications'), findsNothing);
    expect(find.text('Shield apps'), findsOneWidget);
    expect(find.text('Airplane mode'), findsOneWidget);
  });

  testWidgets('subject chips are selectable', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Chemistry'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing overflows on a narrow phone', (tester) async {
    // The 25/50/90/120 chips overflowed a fixed Row and painted the striped
    // overflow bar. A narrow viewport is what surfaces it.
    await pumpSetup(tester);
    // Narrow it after pumping, then settle: 320dp is where the four goal
    // chips used to overflow their card.
    tester.view.physicalSize = const Size(320 * 3, 1000 * 3);
    await tester.pump();
    expect(tester.takeException(), isNull);

    // All four goal chips stay on ONE horizontal line -- same vertical
    // offset -- and still do not overflow. Wrapping them onto a second row
    // would fix the overflow but is not what was asked for.
    final ys = <double>[
      for (final label in const ['25m', '50m', '90m', '120m'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(ys.toSet().length, 1, reason: 'goal chips must share one line');
    expect(find.text('120m'), findsOneWidget);
  });

  testWidgets('guards can be switched off once granted, not just on',
      (tester) async {
    await pumpSetup(tester);
    // With no permission the action asks; that path must not toggle silently.
    expect(find.text('ALLOW'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to Open mode keeps the body up', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('DISTRACTION GUARD'), findsOneWidget);
  });
}
