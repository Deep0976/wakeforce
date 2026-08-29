import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/focus_session.dart';
import 'package:wake_mission_app/models/routine_block.dart';
import 'package:wake_mission_app/services/focus_provider.dart';

/// A whole-app sweep after "0 alarms rang but 100% success rate".
///
/// The rule: a statistic with no data behind it is null, shown as an em dash.
/// Never a flattering 100%, never a punishing 0%. A real zero is still zero.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FocusProvider> loaded() async {
    final f = FocusProvider();
    await f.loadForUser('u1');
    return f;
  }

  FocusSession session({
    required FocusMode mode,
    int goal = 60,
    int seconds = 1800,
  }) =>
      FocusSession(
        id: 's${seconds}_${mode.name}',
        subject: 'Maths',
        mode: mode,
        goalMinutes: mode == FocusMode.open ? 0 : goal,
        actualSeconds: seconds,
        startedAt: DateTime.now(),
        reachedGoal: false,
      );

  RoutineBlock study() => RoutineBlock(
        id: 'b1',
        title: 'Physics',
        startMinute: 8 * 60,
        endMinute: 10 * 60,
        days: {DateTime.now().weekday},
      );

  test('an open session has no time-on-task score, rather than a perfect one',
      () {
    // The old behaviour returned 1.0 -- "100% on task" with no goal at all.
    expect(session(mode: FocusMode.open).timeOnTask, isNull);
  });

  test('a goal session still scores honestly', () {
    // Half of a 60 minute goal.
    expect(session(mode: FocusMode.goal, goal: 60, seconds: 1800).timeOnTask,
        closeTo(0.5, 0.001));
  });

  test('no goal sessions means no average, not zero', () async {
    final focus = await loaded();
    expect(focus.timeOnTask, isNull);
    // An open session must not drag the average into existence either.
    await focus.record(session(mode: FocusMode.open));
    expect(focus.timeOnTask, isNull);
  });

  test('no study blocks means no adherence score, not a failing one', () async {
    final focus = await loaded();
    expect(focus.adherenceFor(const [], DateTime.now()), isNull,
        reason: 'you cannot fail to adhere to a routine you never made');
  });

  test('a planned block that was skipped is a real zero, and shown as one',
      () async {
    final focus = await loaded();
    final rate = focus.adherenceFor([study()], DateTime.now());
    expect(rate, isNotNull, reason: 'there was something to adhere to');
    expect(rate, 0.0, reason: 'a genuine miss must not hide behind a dash');
  });
}
