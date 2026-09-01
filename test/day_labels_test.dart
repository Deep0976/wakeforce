import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/utils/day_labels.dart';

void main() {
  group('shortDateLabel', () {
    test('zero-pads and orders day-month-year', () {
      // The screenshot that prompted this said "Tue 8/9", which is either the
      // 8th of September or the 9th of August.
      expect(shortDateLabel(DateTime(2026, 9, 8)), '08-09-2026');
    });

    test('a day and month that could be swapped are still unambiguous', () {
      expect(shortDateLabel(DateTime(2026, 9, 8)),
          isNot(shortDateLabel(DateTime(2026, 8, 9))));
      expect(shortDateLabel(DateTime(2026, 8, 9)), '09-08-2026');
    });
  });

  group('longDateLabel', () {
    // DateTime.weekday and .month are both 1-based while the label lists are
    // 0-based, so this is where an off-by-one would land.
    test('matches the design\'s "Monday, 18 August"', () {
      expect(longDateLabel(DateTime(2025, 8, 18)), 'Monday, 18 August');
    });

    test('both ends of the week and the year are right', () {
      expect(longDateLabel(DateTime(2025, 1, 5)), 'Sunday, 5 January');
      expect(longDateLabel(DateTime(2025, 12, 31)), 'Wednesday, 31 December');
    });
  });
}
