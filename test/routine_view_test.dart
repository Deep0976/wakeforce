import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/routine_block.dart';
import 'package:wake_mission_app/screens/routine_view.dart';
import 'package:wake_mission_app/services/routine_provider.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// Reproduces the reported bug: "when I add a routine it is not showing
/// anything in it". Exercises the real provider so a regression in either
/// the day filter or the save path fails here rather than on a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// No-op scheduler: AndroidAlarmManager has no platform to talk to here.
  RoutineProvider newProvider() => RoutineProvider(
        scheduler: (_) async {},
        canceller: (_) async {},
      );

  Widget wrap(RoutineProvider provider) => ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: buildWakeForceLightTheme(),
          home: const Scaffold(body: RoutineView()),
        ),
      );

  RoutineBlock blockOn(Set<int> days) => RoutineBlock(
        id: 'b1',
        title: 'Physics — rotational motion',
        startMinute: 8 * 60,
        endMinute: 10 * 60,
        days: days,
      );

  testWidgets('a saved block appears on the timeline', (tester) async {
    final provider = newProvider();
    await provider.loadForUser('uid-1');

    await tester.pumpWidget(wrap(provider));
    expect(find.textContaining('No blocks for today'), findsOneWidget);

    // Every day, so this must show whichever day the suite runs on.
    await provider.upsert(blockOn(const {}));
    await tester.pump();

    expect(find.text('Physics — rotational motion'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.textContaining('No blocks for today'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a block survives being reloaded for the same account',
      (tester) async {
    final provider = newProvider();
    await provider.loadForUser('uid-1');
    await provider.upsert(blockOn(const {}));

    // Simulates the app being reopened: same uid, fresh provider.
    final reopened = newProvider();
    await reopened.loadForUser('uid-1');

    await tester.pumpWidget(wrap(reopened));
    await tester.pump();
    expect(find.text('Physics — rotational motion'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a block only shows on the days it repeats', (tester) async {
    final provider = newProvider();
    await provider.loadForUser('uid-1');

    // Pick a weekday that is definitely not today.
    final today = DateTime.now().weekday;
    final otherDay = today == 7 ? 1 : today + 1;
    await provider.upsert(blockOn({otherDay}));

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    expect(find.textContaining('No blocks for today'), findsOneWidget);

    // Unmount so the view's periodic timer is cancelled before teardown.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('another account does not inherit the first one\'s routine', () async {
    final a = newProvider();
    await a.loadForUser('uid-1');
    await a.upsert(blockOn(const {}));

    final b = newProvider();
    await b.loadForUser('uid-2');
    expect(b.blocks, isEmpty);
  });

  group('saving a block', () {
    test('a block repeating today appears today and is scheduled', () async {
      final scheduled = <String>[];
      final provider = RoutineProvider(
        scheduler: (b) async => scheduled.add(b.id),
        canceller: (_) async {},
      );
      await provider.loadForUser('u1');

      final today = DateTime.now();
      await provider.upsert(RoutineBlock(
        id: 'b-today',
        title: 'Physics',
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        days: {today.weekday},
      ));

      // Appears on the day it was made -- the reported "routine is not
      // showing" was a block saved to Mon-Fri while today was a Saturday.
      expect(provider.blocksFor(today).map((b) => b.id), contains('b-today'));
      // And it actually reached the scheduler, so a reminder can fire.
      expect(scheduled, contains('b-today'));
    });

    test('every block schedules, even with no lead-in and no full alarm',
        () async {
      final scheduled = <String>[];
      final provider = RoutineProvider(
        scheduler: (b) async => scheduled.add(b.id),
        canceller: (_) async {},
      );
      await provider.loadForUser('u1');
      await provider.upsert(RoutineBlock(
        id: 'plain',
        title: 'Lunch',
        startMinute: 13 * 60,
        endMinute: 14 * 60,
        days: {DateTime.now().weekday},
      ));
      expect(scheduled, contains('plain'));
    });
  });
}