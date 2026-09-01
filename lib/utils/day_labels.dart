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

/// "08-09-2026". Zero-padded day-month-year, and deliberately not "8/9":
/// that reads as either the 8th of September or the 9th of August depending
/// on who is holding the phone. The one place this is used is the warning
/// that a block will not fire for another week, so it is the last string in
/// the app that can afford to be ambiguous about which day it means.
String shortDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.year}';
