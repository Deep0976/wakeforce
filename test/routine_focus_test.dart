import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/focus_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_mission_app/models/routine_block.dart';
import 'package:wake_mission_app/services/focus_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RoutineBlock block({
    int start = 8 * 60,
    int end = 10 * 60,
    Set<int> days = const {1, 2, 3, 4, 5},
    BlockType type = BlockType.study,
  }) =>
      RoutineBlock(
        id: 'b1',
        title: 'Physics',
        startMinute: start,
        endMinute: end,
        days: days,
        type: type,
      );

  group('RoutineBlock', () {
    test('is active only inside its window, on a day it repeats', () {
      final b = block(); // Mon-Fri 08:00-10:00
      // 2026-08-17 is a Monday.
      expect(b.isActiveAt(DateTime(2026, 8, 17, 9)), isTrue);
      expect(b.isActiveAt(DateTime(2026, 8, 17, 7, 59)), isFalse);
      // End is exclusive, so the block is over exactly at 10:00.
      expect(b.isActiveAt(DateTime(2026, 8, 17, 10)), isFalse);
      // Saturday isn't in the repeat set.
      expect(b.isActiveAt(DateTime(2026, 8, 22, 9)), isFalse);
    });

    test('an empty repeat set means every day', () {
      final b = block(days: const {});
      expect(b.fallsOn(DateTime(2026, 8, 22)), isTrue);
    });

    test('minutes remaining counts down and never goes negative', () {
      final b = block();
      expect(b.minutesRemainingAt(DateTime(2026, 8, 17, 9, 18)), 42);
      expect(b.minutesRemainingAt(DateTime(2026, 8, 17, 11)), 0);
    });

    test('only study blocks can start a focus session', () {
      expect(BlockType.study.canFocus, isTrue);
      expect(BlockType.breakTime.canFocus, isFalse);
      expect(BlockType.personal.canFocus, isFalse);
    });

    test('survives a round trip through JSON', () {
      final b = block(type: BlockType.personal);
      final back = RoutineBlock.fromJson(b.toJson());
      expect(back.title, b.title);
      expect(back.startMinute, b.startMinute);
      expect(back.days, b.days);
      expect(back.type, BlockType.personal);
    });

    test('an unknown block type from a newer build falls back to study', () {
      final back = RoutineBlock.fromJson({
        'id': 'x',
        'title': 'T',
        'startMinute': 0,
        'endMinute': 60,
        'days': <int>[],
        'type': 'somethingNew',
      });
      expect(back.type, BlockType.study);
    });

    test('a plain block still notifies -- reminders only move it earlier', () {
      // Regression: a block saved with the editor's defaults (no lead-in,
      // not a full alarm) used to schedule nothing at all, so the routine
      // never made a sound.
      expect(block().notifies, isTrue);
      expect(block().nextFireTime(from: DateTime(2026, 8, 17, 7)),
          DateTime(2026, 8, 17, 8, 0));
    });

    test('remind-before pulls the fire time earlier, not the block', () {
      final b = RoutineBlock(
        id: 'x', title: 'T', startMinute: 480, endMinute: 600,
        days: const {1}, remindBeforeMinutes: 10,
      );
      expect(b.nextFireTime(from: DateTime(2026, 8, 17, 7)),
          DateTime(2026, 8, 17, 7, 50));
    });

    test('next fire time lands on the next repeat day', () {
      final b = block(); // Mon-Fri, 08:00
      // Monday 09:00 -> already past today, so Tuesday 08:00.
      final next = b.nextFireTime(from: DateTime(2026, 8, 17, 9));
      expect(next, DateTime(2026, 8, 18, 8));
    });

    test('next fire time subtracts the reminder lead-in', () {
      final b = RoutineBlock(
        id: 'x', title: 'T', startMinute: 8 * 60, endMinute: 10 * 60,
        days: const {1, 2, 3, 4, 5}, remindBeforeMinutes: 10,
      );
      final next = b.nextFireTime(from: DateTime(2026, 8, 17, 6));
      expect(next, DateTime(2026, 8, 17, 7, 50));
    });

    test('a reminder that crosses midnight moves to the previous day', () {
      // 00:10 start with 15m lead-in fires at 23:55 the evening before.
      final b = RoutineBlock(
        id: 'x', title: 'T', startMinute: 10, endMinute: 60,
        days: const {}, remindBeforeMinutes: 15,
      );
      final next = b.nextFireTime(from: DateTime(2026, 8, 17, 12));
      expect(next.hour, 23);
      expect(next.minute, 55);
    });

    test('formats times zero-padded', () {
      expect(RoutineBlock.formatMinute(8 * 60), '08:00');
      expect(RoutineBlock.formatMinute(22 * 60 + 5), '22:05');
    });
  });

  group('adherence', () {
    // 2026-08-18 is a Tuesday.
    final day = DateTime(2026, 8, 18);

    RoutineBlock studyBlock(int startHour, int endHour) => RoutineBlock(
          id: 's$startHour',
          title: 'Study',
          startMinute: startHour * 60,
          endMinute: endHour * 60,
          days: const {},
        );

    FocusSession sessionAt(DateTime start, int minutes) => FocusSession(
          id: 'f',
          subject: 'Physics',
          mode: FocusMode.open,
          goalMinutes: 0,
          actualSeconds: minutes * 60,
          startedAt: start,
          reachedGoal: true,
        );

    test('a day with no study blocks has no score at all', () {
      // Not zero: you cannot fail to adhere to a routine you never made.
      final p = FocusProvider();
      expect(p.adherenceFor(const [], day), isNull);
    });

    test('a block counts as honoured when a session overlaps it', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FocusProvider();
      await p.loadForUser('uid');
      // Sat down at 08:30 for 30 min, inside the 08:00-10:00 block.
      await p.record(sessionAt(DateTime(2026, 8, 18, 8, 30), 30));
      expect(p.adherenceFor([studyBlock(8, 10)], day), 1.0);
    });

    test('a session outside every block honours none of them', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FocusProvider();
      await p.loadForUser('uid');
      await p.record(sessionAt(DateTime(2026, 8, 18, 15), 30));
      expect(p.adherenceFor([studyBlock(8, 10)], day), 0.0);
    });

    test('adherence is the share of blocks actually sat for', () async {
      SharedPreferences.setMockInitialValues({});
      final p = FocusProvider();
      await p.loadForUser('uid');
      await p.record(sessionAt(DateTime(2026, 8, 18, 8, 30), 30));
      expect(
        p.adherenceFor([studyBlock(8, 10), studyBlock(14, 16)], day),
        0.5,
      );
    });

    test('break and personal blocks are not counted against the student', () {
      final p = FocusProvider();
      final breakBlock = RoutineBlock(
        id: 'b', title: 'Lunch', startMinute: 780, endMinute: 840,
        days: const {}, type: BlockType.breakTime,
      );
      // A break block is not something to adhere to, so there is nothing to
      // score -- not a zero held against the student.
      expect(p.adherenceFor([breakBlock], day), isNull);
    });
  });

  group('FocusSession', () {
    FocusSession session({
      FocusMode mode = FocusMode.goal,
      int goal = 90,
      int actual = 90,
      bool reached = true,
    }) =>
        FocusSession(
          id: 's1',
          subject: 'Physics',
          mode: mode,
          goalMinutes: goal,
          actualSeconds: actual * 60,
          startedAt: DateTime(2026, 8, 17, 8),
          reachedGoal: reached,
        );

    test('time on task is the share of the goal actually sat through', () {
      expect(session(goal: 100, actual: 50).timeOnTask, 0.5);
      // Overrunning the goal caps at 1 rather than exceeding it.
      expect(session(goal: 60, actual: 90).timeOnTask, 1.0);
    });

    test('an open session has no goal, so it has no score', () {
      // Previously 1.0 -- a perfect "100% on task" with no goal behind it.
      expect(session(mode: FocusMode.open, goal: 0, actual: 5).timeOnTask,
          isNull);
    });

    test('XP pays per minute, with a bonus for finishing', () {
      expect(session(actual: 40, reached: false).xpEarned, 40);
      expect(session(actual: 40, reached: true).xpEarned, 65);
    });

    test('survives a round trip through JSON', () {
      final s = session(mode: FocusMode.open, goal: 0, actual: 33);
      final back = FocusSession.fromJson(s.toJson());
      expect(back.subject, 'Physics');
      expect(back.mode, FocusMode.open);
      expect(back.actualMinutes, 33);
    });
  });
}
