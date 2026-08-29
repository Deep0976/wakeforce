import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// A Chemistry alarm used to ring in orange because the ringing screen painted
/// everything the app accent instead of asking the mission for its colour.
/// The colour has to mean something, or it is just decoration.
void main() {
  for (final c in [WakeColors.light, WakeColors.dark]) {
    final mode = c == WakeColors.light ? 'light' : 'dark';

    test('$mode: each subject keeps its own colour', () {
      expect(MissionType.math.accentColor(c), c.accent,
          reason: 'Maths is the orange one');
      expect(MissionType.physics.accentColor(c), c.physics,
          reason: 'Physics is the blue one');
      expect(MissionType.typing.accentColor(c), c.done,
          reason: 'Chemistry is the green one');
    });

    test('$mode: Chemistry is never the orange accent', () {
      expect(MissionType.typing.accentColor(c), isNot(c.accent));
      expect(MissionType.physics.accentColor(c), isNot(c.accent));
    });

    test('$mode: the three subjects are mutually distinguishable', () {
      final colours = {
        MissionType.math.accentColor(c),
        MissionType.physics.accentColor(c),
        MissionType.typing.accentColor(c),
      };
      expect(colours.length, 3);
    });
  }

  test('an alarm carries its mission, so the ringing screen can tint itself',
      () {
    final alarm = Alarm(
      id: 'a1',
      hour: 6,
      minute: 0,
      repeatDays: const {},
      missionType: MissionType.typing,
      difficulty: MissionDifficulty.easy,
    );
    expect(alarm.missionType.accentColor(WakeColors.dark), WakeColors.dark.done);
  });
}
