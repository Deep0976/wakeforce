import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/screens/block_editor_screen.dart';
import 'package:wake_mission_app/services/routine_provider.dart';
import 'package:wake_mission_app/utils/day_labels.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// The chip rows must stay on one horizontal line each AND not overflow.
/// Wrapping onto a second row would silence the overflow while breaking the
/// layout that was actually asked for, so both are asserted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpEditor(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final routine =
        RoutineProvider(scheduler: (_) async {}, canceller: (_) async {});
    await routine.loadForUser('u1');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: routine,
        child: MaterialApp(
          theme: buildWakeForceLightTheme(),
          home: const BlockEditorScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  void expectOneLine(WidgetTester tester, List<String> labels) {
    final ys = <double>[
      for (final l in labels) tester.getTopLeft(find.text(l)).dy,
    ];
    expect(ys.toSet().length, 1,
        reason: '$labels must share a single horizontal line');
  }

  testWidgets('remind-before chips stay on one line, no overflow',
      (tester) async {
    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
    expectOneLine(tester, ['At start', '5m', '10m', '15m']);
  });

  testWidgets('block type chips stay on one line', (tester) async {
    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
    expectOneLine(tester, ['Study', 'Break', 'Personal']);
  });

  testWidgets('quick titles stay on one scrollable line, unsquashed',
      (tester) async {
    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
    // All five present on one line; the row scrolls rather than truncating
    // "Chemistry" to a stub or wrapping to a second row.
    expectOneLine(tester, ['Physics', 'Chemistry', 'Maths', 'Lunch', 'Gym']);
  });

  testWidgets('a new block defaults to today, so it shows up straight away',
      (tester) async {
    // The real bug: the default was Mon-Fri, so a block created on a Saturday
    // saved fine and then did not appear, because the timeline shows today.
    // Asserting against DateTime.now().weekday keeps this honest every day of
    // the week, not just at weekends.
    await pumpEditor(tester);
    final todayInitial = weekdayShortLabels[DateTime.now().weekday - 1][0];

    final routine =
        RoutineProvider(scheduler: (_) async {}, canceller: (_) async {});
    await routine.loadForUser('u2');

    await tester.enterText(find.byType(TextField).first, 'Physics');
    await tester.pump();
    expect(todayInitial.isNotEmpty, isTrue);

    // The day pill for today must be selected out of the box.
    final state = tester.state(find.byType(BlockEditorScreen));
    // ignore: avoid_dynamic_calls
    final days = (state as dynamic).testDays as Set<int>;
    expect(days, contains(DateTime.now().weekday),
        reason: 'a new block must repeat on the day it was created');
  });

  testWidgets('still clean on a very narrow screen', (tester) async {
    await pumpEditor(tester, width: 300);
    expect(tester.takeException(), isNull);
  });
}
