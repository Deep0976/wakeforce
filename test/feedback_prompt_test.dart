import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:wake_mission_app/screens/feedback_screen.dart';
import 'package:wake_mission_app/services/feedback_prompt.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// The prompt is counted in solved alarms, not days or alarms set. Nothing is
/// asked until the app has actually woken someone: a student who has only
/// filled in the setup form can rate the form and nothing else. After that it
/// loops with a widening gap, because asking every morning gets the app
/// uninstalled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Random fixed(int value) => _FixedRandom(value);

  test('nothing is asked until an alarm has been solved', () async {
    expect(await FeedbackPrompt.dueAfterMission(0), isFalse);
    expect(await FeedbackPrompt.dueAfterMission(1), isTrue);
  });

  test('round two waits 4 to 8 more solved alarms', () async {
    await FeedbackPrompt.defer(1, random: fixed(0));
    expect(await FeedbackPrompt.dueAfterMission(4), isFalse);
    expect(await FeedbackPrompt.dueAfterMission(5), isTrue);

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await FeedbackPrompt.defer(1, random: fixed(4));
    expect(await FeedbackPrompt.dueAfterMission(8), isFalse);
    expect(await FeedbackPrompt.dueAfterMission(9), isTrue);
  });

  test('each round waits longer than the last', () async {
    var at = 1;
    final gaps = <int>[];
    for (var round = 0; round < 3; round++) {
      await FeedbackPrompt.defer(at, random: fixed(0));
      var next = at + 1;
      while (!await FeedbackPrompt.dueAfterMission(next)) {
        next++;
      }
      gaps.add(next - at);
      at = next;
    }
    expect(gaps, [4, 8, 12]);
  });

  test('the gap is randomised, so a class is not all asked one morning',
      () async {
    final seen = <int>{};
    for (final roll in [0, 1, 2, 3, 4]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await FeedbackPrompt.defer(1, random: fixed(roll));
      var next = 2;
      while (!await FeedbackPrompt.dueAfterMission(next)) {
        next++;
      }
      seen.add(next);
    }
    expect(seen.length, 5, reason: 'every roll must move the next ask');
  });

  test('turning it off is honoured for good', () async {
    await FeedbackPrompt.disable();
    expect(await FeedbackPrompt.dueAfterMission(1), isFalse);
    expect(await FeedbackPrompt.dueAfterMission(999), isFalse);
  });

  test('round one asks about the first wake-up, later rounds about living '
      'with it', () async {
    expect(await FeedbackPrompt.topic(), FeedbackTopic.firstWake);
    await FeedbackPrompt.defer(1);
    expect(await FeedbackPrompt.topic(), FeedbackTopic.usage);
  });

  testWidgets('the form will not send an unrated answer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildWakeForceLightTheme(),
      home: const FeedbackScreen(
        topic: FeedbackTopic.firstWake,
        initialStars: 0,
        solvedAlarms: 1,
      ),
    ));
    await tester.pump();

    for (final reason in FeedbackTopic.firstWake.reasons) {
      expect(find.text(reason), findsOneWidget);
    }

    final send = find.text('Send feedback');
    expect(send, findsOneWidget);

    double sendOpacity() => tester
        .widget<Opacity>(
            find.ancestor(of: send, matching: find.byType(Opacity)).first)
        .opacity;

    expect(sendOpacity(), lessThan(1),
        reason: 'Send is dimmed until a star is picked');

    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pump();

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(sendOpacity(), 1, reason: 'four stars is a rating, so Send lives');
  });

  testWidgets('the confirmation shows the note the student actually typed',
      (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(MaterialApp(
      theme: buildWakeForceLightTheme(),
      home: const FeedbackScreen(
        topic: FeedbackTopic.firstWake,
        initialStars: 4,
        solvedAlarms: 1,
      ),
    ));
    await tester.pump();

    const note = 'Let me copy an alarm instead of making a new one';
    await tester.enterText(find.byType(TextField), note);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Thanks — noted'), findsOneWidget);
    expect(find.text('“$note”'), findsOneWidget,
        reason: 'their own words, so they can see what was sent');
  });

  testWidgets('the confirmation stands on its own, for a card-only rating',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildWakeForceLightTheme(),
      home: const FeedbackScreen.sent(),
    ));
    await tester.pump();

    expect(find.text('Thanks — noted'), findsOneWidget);
    expect(find.text('Send feedback'), findsNothing);
    expect(find.text('Turn off feedback requests'), findsOneWidget);
  });
}

class _FixedRandom implements Random {
  final int value;
  _FixedRandom(this.value);

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
