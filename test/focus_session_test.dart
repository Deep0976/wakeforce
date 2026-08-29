import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/focus_session.dart';

/// "I did focus mode for 20 seconds and it did not come in my progress."
/// Sessions used to be stored in whole minutes, so anything under a minute
/// truncated to zero: no XP, nothing in Progress, "0m" on the summary.
void main() {
  FocusSession session(int seconds, {int goal = 90, bool reached = false}) =>
      FocusSession(
        id: 's',
        subject: 'Maths',
        mode: FocusMode.goal,
        goalMinutes: goal,
        actualSeconds: seconds,
        startedAt: DateTime(2026, 8, 29, 12),
        reachedGoal: reached,
      );

  test('a 20 second sitting is recorded, not rounded away', () {
    final s = session(20);
    expect(s.actualSeconds, 20);
    expect(s.durationLabel, '20s');
    expect(s.xpEarned, greaterThan(0), reason: 'real work must earn something');
  });

  test('a sitting of zero seconds earns nothing', () {
    expect(session(0).xpEarned, 0);
  });

  test('longer sittings still read in minutes and hours', () {
    expect(session(4 * 60).durationLabel, '4m');
    expect(session(3780).durationLabel, '1h 03m');
  });

  test('time on task is measured in seconds, not truncated minutes', () {
    // 30s of a 1 minute goal is half, not zero.
    expect(session(30, goal: 1).timeOnTask, closeTo(0.5, 0.001));
  });

  test('old records stored in minutes still load', () {
    final back = FocusSession.fromJson({
      'id': 'old',
      'subject': 'Physics',
      'mode': 'goal',
      'goalMinutes': 60,
      'actualMinutes': 45,
      'startedAt': '2026-08-01T10:00:00.000',
      'reachedGoal': true,
    });
    expect(back.actualSeconds, 45 * 60);
    expect(back.actualMinutes, 45);
  });
}
