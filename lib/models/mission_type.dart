import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The four missions in the design: Maths, Physics, Chemistry, Shake.
///
/// `typing` is the legacy enum name for the Chemistry quiz and `photo` is the
/// retired Photo mission -- both names are persisted in saved alarms and in
/// analytics, so they stay put rather than being renamed.
enum MissionType { math, physics, shake, typing, photo }

/// What the picker offers. Photo is excluded: it was cut from the design and
/// recorded zero uses in 28 days, but the value survives so alarms saved
/// against it still decode.
const kSelectableMissions = [
  MissionType.math,
  MissionType.physics,
  MissionType.typing,
  MissionType.shake,
];

extension MissionTypeX on MissionType {
  String get label {
    switch (this) {
      case MissionType.math:
        return 'Maths';
      case MissionType.physics:
        return 'Physics Quiz';
      case MissionType.shake:
        return 'Shake Phone';
      case MissionType.typing:
        return 'Chemistry Quiz';
      case MissionType.photo:
        return 'Photo Mission';
    }
  }

  /// Fits the 2x2 picker tile, where the full label wraps awkwardly.
  String get shortLabel {
    switch (this) {
      case MissionType.math:
        return 'Maths';
      case MissionType.physics:
        return 'Physics';
      case MissionType.shake:
        return 'Shake';
      case MissionType.typing:
        return 'Chemistry';
      case MissionType.photo:
        return 'Photo';
    }
  }

  String get description {
    switch (this) {
      case MissionType.math:
        return 'Solve a JEE-level maths question to stop the alarm';
      case MissionType.physics:
        return 'Solve a JEE-level physics question to stop the alarm';
      case MissionType.shake:
        return 'Shake your phone to stop the alarm';
      case MissionType.typing:
        return 'Answer a JEE-level chemistry question to stop the alarm';
      case MissionType.photo:
        return 'Match a photo of your notes to stop the alarm';
    }
  }

  IconData get icon {
    switch (this) {
      case MissionType.math:
        return Icons.calculate_outlined;
      case MissionType.physics:
        return Icons.bolt_outlined;
      case MissionType.shake:
        return Icons.vibration;
      case MissionType.typing:
        return Icons.science_outlined;
      case MissionType.photo:
        return Icons.camera_alt_outlined;
    }
  }

  /// Each mission owns one hue from the palette, so a row/tile reads as that
  /// subject at a glance. Resolved from the theme rather than hardcoded --
  /// the light and dark palettes use different values for the same role.
  Color accentColor(WakeColors c) {
    switch (this) {
      case MissionType.math:
        return c.accent;
      case MissionType.physics:
        return c.physics;
      case MissionType.shake:
        return c.personal;
      case MissionType.typing:
        return c.done;
      case MissionType.photo:
        return c.physics;
    }
  }
}
