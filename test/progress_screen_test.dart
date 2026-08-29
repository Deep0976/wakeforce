import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/focus_session.dart';
import 'package:wake_mission_app/screens/progress_screen.dart';
import 'package:wake_mission_app/services/focus_provider.dart';
import 'package:wake_mission_app/services/routine_provider.dart';
import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/services/stats_provider.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// "focus of progress it is not showing" -- is the card missing, or is it
/// rendering real zeros? These pin the answer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FocusProvider> pumpProgress(
    WidgetTester tester, {
    List<FocusSession> sessions = const [],
  }) async {
    final focus = FocusProvider();
    await focus.loadForUser('u1');
    for (final s in sessions) {
      await focus.record(s);
    }
    final stats = StatsProvider();
    await stats.loadForUser('u1');
    final routine = RoutineProvider(scheduler: (_) async {}, canceller: (_) async {});
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
          home: const ProgressScreen(),
        ),
      ),
    );
    await tester.pump();
    return focus;
  }

  testWidgets('the Focus & routine card renders even with no sessions',
      (tester) async {
    await pumpProgress(tester);
    expect(tester.takeException(), isNull);
    // SectionLabel uppercases its text.
    expect(find.text('FOCUS & ROUTINE'), findsOneWidget);
    // Zero state explains what to do rather than showing 0 three times.
    expect(find.textContaining('No focus sessions yet'), findsOneWidget);
    expect(find.text('focused'), findsNothing);
  });

  testWidgets('a recorded session shows up in focused hours', (tester) async {
    await pumpProgress(tester, sessions: [
      FocusSession(
        id: 's1',
        subject: 'Physics',
        mode: FocusMode.goal,
        goalMinutes: 90,
        actualSeconds: 5400,
        startedAt: DateTime.now(),
        reachedGoal: true,
      ),
    ]);
    expect(tester.takeException(), isNull);
    // Once a session exists the real tiles replace the zero state.
    expect(find.textContaining('No focus sessions yet'), findsNothing);
    expect(find.text('focused'), findsOneWidget);
    expect(find.text('0h'), findsNothing);
  });

  testWidgets('no raw Dart shows through on screen', (tester) async {
    // An escaped interpolation -- '\${x}' instead of '${x}' -- is a perfectly
    // valid Dart string, so the analyzer and the compiler both accept it and
    // the app renders the source code to the student. Only looking at the
    // rendered text catches it.
    tester.view.physicalSize = const Size(400 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final focus = FocusProvider();
    await focus.loadForUser('u1');
    await focus.record(FocusSession(
      id: 'f1',
      subject: 'Maths',
      mode: FocusMode.goal,
      goalMinutes: 60,
      actualSeconds: 1800,
      startedAt: DateTime.now(),
      reachedGoal: false,
    ));

    final stats = StatsProvider();
    await stats.loadForUser('u1');
    // Real data on every counter, so every interpolation actually renders.
    await stats.recordMissionAttempted();
    await stats.recordMissionCompleted(
        MissionType.math, MissionDifficulty.easy);

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
          home: const ProgressScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final shown = t.data ?? t.textSpan?.toPlainText() ?? '';
      expect(shown.contains(r'${'), isFalse,
          reason: 'unrendered interpolation on screen: $shown');
      expect(shown.contains(r'\$'), isFalse,
          reason: 'escaped dollar on screen: $shown');
    }
  });
}
