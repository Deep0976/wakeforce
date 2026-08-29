import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/theme/app_theme.dart';
import 'package:wake_mission_app/widgets/alarm_tile.dart';

/// Pumps [child] inside a real WakeForce theme so WakeColors resolves.
Widget _wrap(Widget child, {required bool dark}) {
  return MaterialApp(
    theme: dark ? buildWakeForceDarkTheme() : buildWakeForceLightTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('palette', () {
    // Asserted against the const palettes rather than a built ThemeData:
    // building one resolves Poppins, which google_fonts fetches over the
    // network and cannot do in a test.
    test('matches the spec', () {
      expect(WakeColors.light.bg, const Color(0xFFFAF7F4));
      expect(WakeColors.light.card, const Color(0xFFFFFFFF));
      expect(WakeColors.light.accent, const Color(0xFFEF6A00));

      expect(WakeColors.dark.bg, const Color(0xFF0D1117));
      expect(WakeColors.dark.card, const Color(0xFF161C24));
      expect(WakeColors.dark.accent, const Color(0xFFFF7A1A));
    });

    test('one elevation only: light uses shadow, dark uses a border', () {
      expect(WakeColors.light.cardShadow, isNotEmpty);
      expect(WakeColors.light.cardBorder, isNull);

      expect(WakeColors.dark.cardShadow, isEmpty);
      expect(WakeColors.dark.cardBorder, isNotNull);
    });

    test('orange is never used as body text on light', () {
      // #EF6A00 fails contrast as text on #FAF7F4, so the spec keeps a
      // darker ink for text and reserves the bright orange for fills.
      expect(WakeColors.light.accentInk, isNot(WakeColors.light.accent));
    });

    test('every selectable mission resolves to its own hue', () {
      // Only the four in the picker need to be distinguishable; retired
      // Photo deliberately reuses the Physics blue.
      for (final c in [WakeColors.light, WakeColors.dark]) {
        final colors =
            kSelectableMissions.map((m) => m.accentColor(c)).toList();
        expect(colors.toSet().length, kSelectableMissions.length,
            reason: 'missions must be distinguishable by colour alone');
        expect(MissionType.math.accentColor(c), c.accent);
        expect(MissionType.physics.accentColor(c), c.physics);
      }
    });

    test('the picker offers exactly the four missions in the design', () {
      expect(kSelectableMissions, [
        MissionType.math,
        MissionType.physics,
        MissionType.typing,
        MissionType.shake,
      ]);
      expect(kSelectableMissions, isNot(contains(MissionType.photo)));
    });
  });

  testWidgets('both themes expose WakeColors through context', (tester) async {
    for (final dark in [true, false]) {
      late WakeColors resolved;
      await tester.pumpWidget(
        _wrap(
          Builder(builder: (context) {
            resolved = context.wake;
            return const SizedBox.shrink();
          }),
          dark: dark,
        ),
      );
      // MaterialApp lerps between themes, so the first frame after a theme
      // swap still carries the previous palette.
      await tester.pumpAndSettle();

      final expected = dark ? WakeColors.dark : WakeColors.light;
      expect(resolved.bg, expected.bg);
      expect(resolved.card, expected.card);
      expect(resolved.accent, expected.accent);
      expect(resolved.textPrimary, expected.textPrimary);
    }
  });

  group('AlarmTile', () {
    Alarm alarmAt({bool enabled = true}) => Alarm(
          id: 'a1',
          hour: 6,
          minute: 0,
          repeatDays: const {1, 2, 3, 4, 5},
          missionType: MissionType.typing,
          enabled: enabled,
        );

    testWidgets('shows the time and the mission name', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlarmTile(
            alarm: alarmAt(),
            onToggle: (_) {},
            onTap: () {},
          ),
          dark: true,
        ),
      );

      expect(find.text('06:00'), findsOneWidget);
      expect(find.textContaining('Chemistry Quiz'), findsOneWidget);
    });

    testWidgets('renders in both themes', (tester) async {
      for (final dark in [true, false]) {
        await tester.pumpWidget(
          _wrap(
            AlarmTile(alarm: alarmAt(), onToggle: (_) {}, onTap: () {}),
            dark: dark,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(Switch), findsOneWidget);
      }
    });

    testWidgets('the switch reflects the alarm being off', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AlarmTile(
            alarm: alarmAt(enabled: false),
            onToggle: (_) {},
            onTap: () {},
          ),
          dark: false,
        ),
      );

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });
  });
}
