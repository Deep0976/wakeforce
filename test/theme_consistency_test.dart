import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wake_mission_app/missions/shake_mission.dart';
import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/theme/app_theme.dart';

/// Missions render inside the mission screen, which follows the app theme.
/// Hardcoded white was invisible on the light background -- these pin that
/// every mission takes its colours from the theme instead.
void main() {
  Widget wrap(Widget child, ThemeData theme) => MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: child)),
      );

  for (final entry in {
    'light': buildWakeForceLightTheme(),
    'dark': buildWakeForceDarkTheme(),
  }.entries) {
    final mode = entry.key;
    final theme = entry.value;

    testWidgets('$mode: the shake mission paints no raw white', (tester) async {
      await tester.pumpWidget(wrap(
        ShakeMission(
          difficulty: MissionDifficulty.easy,
          onComplete: () {},
        ),
        theme,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final colour = t.style?.color;
        expect(colour, isNot(Colors.white),
            reason: 'raw white is invisible on the light background');
        expect(colour, isNot(Colors.white70));
      }
      for (final i in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(i.color, isNot(Colors.white));
      }
    });
  }

  test('both palettes define every role, so nothing falls back silently', () {
    for (final c in [WakeColors.light, WakeColors.dark]) {
      for (final colour in [
        c.bg, c.card, c.accent, c.accentInk, c.done,
        c.personal, c.physics, c.divider,
        c.textPrimary, c.textSecondary, c.textMuted, c.textFaint,
      ]) {
        expect(colour.a, greaterThan(0), reason: 'a role is fully transparent');
      }
    }
  });

  test('dark and light are genuinely different, not the same palette twice',
      () {
    expect(WakeColors.dark.bg, isNot(WakeColors.light.bg));
    expect(WakeColors.dark.card, isNot(WakeColors.light.card));
    expect(WakeColors.dark.textPrimary, isNot(WakeColors.light.textPrimary));
  });

  test('text stays readable against the background in both themes', () {
    double luminance(Color x) => x.computeLuminance();
    for (final c in [WakeColors.light, WakeColors.dark]) {
      final bg = luminance(c.bg);
      // Primary text must sit on the opposite side of mid-grey from the page.
      final text = luminance(c.textPrimary);
      expect((bg - text).abs(), greaterThan(0.4),
          reason: 'primary text has too little contrast with the background');
    }
  });

  test('both themes keep four distinct levels of type', () {
    for (final c in [WakeColors.light, WakeColors.dark]) {
      final levels = {c.textPrimary, c.textSecondary, c.textMuted, c.textFaint};
      expect(levels.length, 4,
          reason: 'a type level is duplicated, so hierarchy is lost');
    }
  });

  test('faint text is lighter than muted, and muted lighter than secondary',
      () {
    for (final c in [WakeColors.light, WakeColors.dark]) {
      final towardsBg = c.bg.computeLuminance() > 0.5 ? 1 : -1;
      double d(Color x) => x.computeLuminance() * towardsBg;
      expect(d(c.textFaint), greaterThan(d(c.textMuted)));
      expect(d(c.textMuted), greaterThan(d(c.textSecondary)));
      expect(d(c.textSecondary), greaterThan(d(c.textPrimary)));
    }
  });

  test('subject colours stay distinct from each other in dark mode', () {
    final c = WakeColors.dark;
    final subjects = {
      MissionType.math.accentColor(c),
      MissionType.physics.accentColor(c),
      MissionType.typing.accentColor(c),
      MissionType.shake.accentColor(c),
    };
    expect(subjects.length, 4);
  });
}
