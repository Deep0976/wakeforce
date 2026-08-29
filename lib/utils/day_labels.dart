import 'package:flutter/foundation.dart' show setEquals;

const List<String> weekdayShortLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String repeatSummary(Set<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  if (setEquals(days, {1, 2, 3, 4, 5})) return 'Weekdays';
  if (setEquals(days, {6, 7})) return 'Weekends';
  final sorted = days.toList()..sort();
  return sorted.map((d) => weekdayShortLabels[d - 1]).join(', ');
}

const List<String> weekdayLongLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> monthLongLabels = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Monday, 18 August" -- the ringing screen's date line. Written out rather
/// than pulling in intl for one string.
String longDateLabel(DateTime d) =>
    '${weekdayLongLabels[d.weekday - 1]}, ${d.day} ${monthLongLabels[d.month - 1]}';
