import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/routine_block.dart';

/// The reported bug: "I set lunch for 12:30 with a 5 minute reminder and it
/// never rang." The block had been saved for 00:30 (12:30 AM), that time had
/// already passed, and it silently rolled a week out.
void main() {
  RoutineBlock lunch({required int startMinute, Set<int>? days}) => RoutineBlock(
        id: 'lunch',
        title: 'Lunch',
        startMinute: startMinute,
        endMinute: startMinute + 60,
        days: days ?? {6}, // Saturday
        remindBeforeMinutes: 5,
      );

  test('12:30 PM lunch fires at 12:25 the same day', () {
    // Saturday 29 Aug 2026, 00:30.
    final now = DateTime(2026, 8, 29, 0, 30);
    final fire = lunch(startMinute: 12 * 60 + 30).nextFireTime(from: now);
    expect(fire, DateTime(2026, 8, 29, 12, 25));
  });

  test('12:30 AM lunch, already past, rolls a full week -- and that is a '
      'week the student must be told about', () {
    final now = DateTime(2026, 8, 29, 0, 30);
    final fire = lunch(startMinute: 30).nextFireTime(from: now);
    // Exactly the trap: same weekday, seven days later.
    expect(fire, DateTime(2026, 9, 5, 0, 25));
    expect(fire.difference(now).inDays, 6);
  });

  test('a block later today fires today, not next week', () {
    final now = DateTime(2026, 8, 29, 9, 0);
    final fire = lunch(startMinute: 12 * 60 + 30).nextFireTime(from: now);
    expect(fire, DateTime(2026, 8, 29, 12, 25));
  });

  test('midnight start with a lead-in fires the previous evening', () {
    // 00:10 start with a 15m lead-in must fire at 23:55 the day before, not
    // clamp to 00:00.
    final b = RoutineBlock(
      id: 'x', title: 'Late', startMinute: 10, endMinute: 70,
      days: {6}, remindBeforeMinutes: 15,
    );
    final fire = b.nextFireTime(from: DateTime(2026, 8, 28, 12, 0));
    expect(fire, DateTime(2026, 8, 28, 23, 55));
  });

  group('startsFocus', () {
    test('survives a round trip, so the ringing screen can act on it', () {
      final b = RoutineBlock(
        id: 'f', title: 'Physics', startMinute: 480, endMinute: 600,
        days: {1}, startsFocus: true, ringAsAlarm: true,
      );
      final back = RoutineBlock.fromJson(b.toJson());
      expect(back.startsFocus, isTrue);
      expect(back.ringAsAlarm, isTrue);
    });

    test('only study blocks can start a focus session', () {
      expect(BlockType.study.canFocus, isTrue);
      expect(BlockType.breakTime.canFocus, isFalse);
      expect(BlockType.personal.canFocus, isFalse);
    });
  });
}
