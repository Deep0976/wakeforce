import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/routine_block.dart';
import 'package:wake_mission_app/screens/block_ringing_screen.dart';
import 'package:wake_mission_app/services/routine_provider.dart';
import 'package:wake_mission_app/theme/app_theme.dart';
import 'package:wake_mission_app/widgets/subject_icon.dart';

/// Design 4o. Light and subject-tinted, with snooze and skip -- deliberately
/// unlike the wake alarm, which has neither.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  RoutineBlock physics() => RoutineBlock(
        id: 'p1',
        title: 'Physics — rotational motion',
        startMinute: 8 * 60,
        endMinute: 10 * 60,
        days: {1, 2, 3, 4, 5, 6},
        remindBeforeMinutes: 10,
        startsFocus: true,
      );

  Future<void> pumpRinging(WidgetTester tester, RoutineBlock block) async {
    tester.view.physicalSize = const Size(400 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final routine =
        RoutineProvider(scheduler: (_) async {}, canceller: (_) async {});
    await routine.loadForUser('u1');
    await routine.upsert(block);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: routine,
        child: MaterialApp(
          theme: buildWakeForceLightTheme(),
          home: BlockRingingScreen(block: block),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the 4o layout without overflowing', (tester) async {
    await pumpRinging(tester, physics());
    expect(tester.takeException(), isNull);
    expect(find.text('ROUTINE ALARM'), findsOneWidget);
    // Title splits: big subject heading, detail in the card below.
    expect(find.text('Physics'), findsOneWidget);
    expect(find.text('rotational motion'), findsOneWidget);
    expect(find.text('Start focus now  →'), findsOneWidget);
    expect(find.text('Snooze 5 min'), findsOneWidget);
    expect(find.text('Skip today'), findsOneWidget);
  });

  testWidgets('a break block offers no focus, only dismiss', (tester) async {
    await pumpRinging(
      tester,
      RoutineBlock(
        id: 'b1',
        title: 'Lunch',
        startMinute: 13 * 60,
        endMinute: 14 * 60,
        days: {6},
        type: BlockType.breakTime,
      ),
    );
    expect(tester.takeException(), isNull);
    // You cannot focus on a lunch break, so the primary action is not focus.
    expect(find.text('Start focus now  →'), findsNothing);
    expect(find.text('Start break'), findsOneWidget);
    // Snooze and skip still apply.
    expect(find.text('Snooze 5 min'), findsOneWidget);
  });

  testWidgets('a title with no dash still renders', (tester) async {
    await pumpRinging(
      tester,
      RoutineBlock(
        id: 'n1',
        title: 'Revision',
        startMinute: 20 * 60,
        endMinute: 21 * 60,
        days: {6},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Revision'), findsOneWidget);
  });

  testWidgets('survives a narrow screen', (tester) async {
    await pumpRinging(tester, physics());
    tester.view.physicalSize = const Size(320 * 3, 1000 * 3);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a personal block offers to silence the phone', (tester) async {
    await pumpRinging(
      tester,
      RoutineBlock(
        id: 'g1',
        title: 'Gym — leg day',
        startMinute: 17 * 60,
        endMinute: 18 * 60,
        days: {6},
        type: BlockType.personal,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Silence my phone'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
  });

  testWidgets('Physics uses the drawn atom, not a Material icon',
      (tester) async {
    await pumpRinging(tester, physics());
    // The atom is custom-painted because Material has no atom glyph; if this
    // ever falls back to an Icon the subject symbols have diverged again.
    expect(find.byType(AtomIcon), findsOneWidget);
  });
}
