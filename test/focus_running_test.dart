import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/focus_session.dart';
import 'package:wake_mission_app/screens/focus_complete_screen.dart';
import 'package:wake_mission_app/screens/focus_running_screen.dart';
import 'package:wake_mission_app/services/focus_provider.dart';
import 'package:wake_mission_app/services/routine_provider.dart';
import 'package:wake_mission_app/services/stats_provider.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// "It does not matter if I did 10 seconds or 1 hour, this screen should come,
/// and it should reflect in Progress."
///
/// Ending under a minute used to pop straight out without recording anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Wakelock and the focus channel have no platform here; answer them so the
    // screen builds instead of throwing.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/wakelock_plus'),
      (call) async => call.method == 'isEnabled' ? false : null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('wakeforce/focus'),
      (call) async => false,
    );
  });

  Future<FocusProvider> pumpRunning(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final focus = FocusProvider();
    await focus.loadForUser('u1');
    final stats = StatsProvider();
    final routine =
        RoutineProvider(scheduler: (_) async {}, canceller: (_) async {});
    await routine.loadForUser('u1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider.value(value: stats),
          ChangeNotifierProvider.value(value: routine),
        ],
        child: MaterialApp(
          theme: buildWakeForceLightTheme(),
          home: const FocusRunningScreen(
            subject: 'Maths',
            mode: FocusMode.goal,
            goalMinutes: 90,
          ),
        ),
      ),
    );
    await tester.pump();
    return focus;
  }

  testWidgets('a 20 second session is recorded and shows its summary',
      (tester) async {
    final focus = await pumpRunning(tester);

    // Let 20 seconds of session time elapse.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.tap(find.text('End session'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The summary screen appears, however short the sitting was.
    expect(find.byType(FocusCompleteScreen), findsOneWidget);

    // And it reached Progress: a real session with real seconds on it.
    expect(focus.sessions, hasLength(1));
    expect(focus.sessions.single.actualSeconds, greaterThan(0));
    expect(focus.sessions.single.xpEarned, greaterThan(0));
  });
}
