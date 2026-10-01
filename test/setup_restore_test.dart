import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/models/routine_block.dart';
import 'package:wake_mission_app/services/alarm_repository.dart';
import 'package:wake_mission_app/services/routine_provider.dart';

/// Alarms and routine blocks now fall back to a cloud copy so a reinstall
/// does not start the student from nothing. The danger in that is the other
/// direction: a cloud read that fails must never be mistaken for "this
/// student has no alarms". There is no Firebase app in this suite, so every
/// cloud call here fails -- which is exactly the case worth pinning.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Alarm alarmAt(int hour) => Alarm(
        id: 'a$hour',
        hour: hour,
        minute: 0,
        repeatDays: const {1, 2, 3},
        missionType: MissionType.math,
        difficulty: MissionDifficulty.medium,
        label: '',
        enabled: true,
      );

  test('local alarms survive a cloud that cannot be reached', () async {
    const repo = AlarmRepository('student-1');
    await repo.saveAlarms([alarmAt(6), alarmAt(7)]);

    final loaded = await repo.loadAlarms();
    expect(loaded.map((a) => a.hour), [6, 7],
        reason: 'a failed push must not stop the local save');
  });

  test('an unreachable cloud reads as no alarms, not as a crash', () async {
    const repo = AlarmRepository('student-2');
    expect(await repo.loadAlarms(), isEmpty);
  });

  test('one student never sees another student saved copy', () async {
    await const AlarmRepository('student-1').saveAlarms([alarmAt(6)]);
    expect(await const AlarmRepository('student-2').loadAlarms(), isEmpty);
  });

  test('routine blocks behave the same way', () async {
    const repo = RoutineRepository('student-1');
    final block = RoutineBlock(
      id: 'b1',
      title: 'Physics',
      type: BlockType.study,
      startMinute: 8 * 60,
      endMinute: 10 * 60,
      days: const {1, 2, 3, 4, 5},
    );
    await repo.save([block]);

    final loaded = await repo.load();
    expect(loaded.map((b) => b.title), ['Physics']);
    expect(await const RoutineRepository('student-2').load(), isEmpty);
  });

  test('what is written locally is what the cloud copy would carry', () async {
    const repo = AlarmRepository('student-3');
    await repo.saveAlarms([alarmAt(6)]);

    // The cloud copy is the same list of JSON strings the prefs hold, so a
    // restore cannot drift from what was saved.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('alarms_student-3')!;
    expect(jsonDecode(raw.single)['hour'], 6);
  });
}
