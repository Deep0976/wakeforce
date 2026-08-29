import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/utils/day_labels.dart';

void main() {
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
