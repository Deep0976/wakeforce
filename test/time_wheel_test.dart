import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/theme/app_theme.dart';
import 'package:wake_mission_app/widgets/time_wheel.dart';

/// The wheels loop, so 12 rolls back to 01. A looping CupertinoPicker reports
/// a RAW scroll index that runs negative and past the end -- these pin that it
/// is folded back into a real time instead of producing hour 0 or hour 16.
void main() {
  Future<int?> pumpAndSpin(
    WidgetTester tester, {
    required int initialMinutes,
    required double dy,
    required int wheel, // 0 = hour, 1 = minute
  }) async {
    int? emitted;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildWakeForceLightTheme(),
        home: Scaffold(
          body: Center(
            child: TimeWheel(
              initialMinutes: initialMinutes,
              onChanged: (v) => emitted = v,
            ),
          ),
        ),
      ),
    );
    final wheels = find.byType(ListWheelScrollView);
    await tester.drag(wheels.at(wheel), Offset(0, dy));
    await tester.pumpAndSettle();
    return emitted;
  }

  test('Dart modulo folds a negative raw index back into range', () {
    // The property the fix relies on: unlike C, Dart's % is non-negative for
    // a positive divisor.
    expect(-1 % 12, 11);
    expect(-13 % 12, 11);
    expect(-1 % 60, 59);
  });

  testWidgets('spinning the hour wheel up past the start stays a valid time',
      (tester) async {
    // 01:00 AM, dragged down -- scrolls the hour below index 0.
    final v = await pumpAndSpin(
      tester, initialMinutes: 60, dy: 220, wheel: 0,
    );
    expect(v, isNotNull);
    expect(v! >= 0 && v < 24 * 60, isTrue,
        reason: 'emitted $v is not a valid minute-of-day');
  });

  testWidgets('spinning the hour wheel down past the end stays valid',
      (tester) async {
    // 11:00 AM, dragged up -- scrolls the hour past index 11.
    final v = await pumpAndSpin(
      tester, initialMinutes: 11 * 60, dy: -220, wheel: 0,
    );
    expect(v, isNotNull);
    expect(v! >= 0 && v < 24 * 60, isTrue,
        reason: 'emitted $v is not a valid minute-of-day');
  });

  testWidgets('spinning the minute wheel past 59 stays valid', (tester) async {
    final v = await pumpAndSpin(
      tester, initialMinutes: 59, dy: -220, wheel: 1,
    );
    expect(v, isNotNull);
    expect(v! % 60 >= 0 && v % 60 < 60, isTrue);
    expect(v >= 0 && v < 24 * 60, isTrue);
  });
}
