import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mission_type.dart';

/// The one place subject glyphs are defined.
///
/// Maths, Physics and Chemistry look the same everywhere they appear -- the
/// alarm list, the mission picker, the ringing screens and the routine
/// timeline -- so a student learns one symbol per subject rather than three.
///
/// Physics is a drawn atom because Material has no atom icon and the nearest
/// stand-ins (a lightning bolt, a blur) say nothing about physics.
Widget missionGlyph(MissionType type, {required double size, required Color color}) {
  if (type == MissionType.physics) {
    return AtomIcon(size: size, color: color);
  }
  return Icon(type.icon, size: size, color: color);
}

/// Routine blocks are free text, so the glyph is matched from the title and
/// falls back to a neutral one. Keeps "Physics — rotational motion" showing
/// the same atom the Physics mission uses.
Widget? subjectGlyphForTitle(
  String title, {
  required double size,
  required Color color,
}) {
  final t = title.toLowerCase();
  // Physics is drawn, so it is handled before the font-glyph lookup. There is
  // deliberately no placeholder IconData standing in for it: a fake IconData
  // reads as a real font reference to the release build's icon tree-shaker,
  // and any caller who rendered it would get an empty box.
  if (t.contains('physics')) return AtomIcon(size: size, color: color);
  final icon = _iconForTitle(t);
  return icon == null ? null : Icon(icon, size: size, color: color);
}

/// Matches on the block's own words rather than its type.
///
/// A block called "Lunch" is created as a Study block by default, so keying
/// the glyph off the type alone showed a textbook next to the word Lunch.
/// What the student wrote is the better signal.
IconData? _iconForTitle(String t) {
  if (t.contains('chem')) return Icons.science_outlined;
  if (t.contains('math') || t.contains('calc')) return Icons.calculate_outlined;
  if (t.contains('lunch') ||
      t.contains('dinner') ||
      t.contains('breakfast') ||
      t.contains('meal') ||
      t.contains('eat') ||
      t.contains('food')) {
    return Icons.restaurant;
  }
  if (t.contains('gym') ||
      t.contains('workout') ||
      t.contains('exercise') ||
      t.contains('run')) {
    return Icons.fitness_center;
  }
  if (t.contains('sleep') || t.contains('nap') || t.contains('rest')) {
    return Icons.bedtime_outlined;
  }
  if (t.contains('break') || t.contains('tea') || t.contains('coffee')) {
    return Icons.local_cafe_outlined;
  }
  if (t.contains('revis')) return Icons.history_edu_outlined;
  if (t.contains('biolog')) return Icons.biotech_outlined;
  if (t.contains('english')) return Icons.menu_book_outlined;
  return null;
}

/// A nucleus with electron orbits round it, drawn rather than pulled from an
/// icon font so it stays crisp at every size it is used at.
class AtomIcon extends StatelessWidget {
  final double size;
  final Color color;

  const AtomIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AtomPainter(color)),
    );
  }
}

class _AtomPainter extends CustomPainter {
  final Color color;

  const _AtomPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    // Material icons are drawn on a 24dp grid with roughly 2dp of padding a
    // side, so their artwork fills about 84% of the box they are given. This
    // one is painted edge to edge, so without the same inset Physics reads
    // noticeably larger than Maths and Chemistry sitting beside it.
    final s = size.width * 0.84;

    // Two orbits crossed at 45 degrees, not the conventional three. Three
    // ellipses overlap so heavily near the middle that at 16-20px -- an alarm
    // row, a picker tile -- the glyph fills in and reads as a dark blob. Two
    // keeps the centre open at every size the app draws it.
    final stroke = math.max(1.0, s * 0.055);

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..isAntiAlias = true;

    final nucleus = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    // Rotated 45 degrees, an ellipse this wide still sits inside the box:
    // its rotated half-extent is ~0.40s against the 0.5s available.
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: s * 0.98,
      height: s * 0.50,
    );

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    for (final turn in const [-math.pi / 4, math.pi / 4]) {
      canvas.save();
      canvas.rotate(turn);
      canvas.drawOval(rect, orbit);
      canvas.restore();
    }
    canvas.restore();

    canvas.drawCircle(centre, s * 0.125, nucleus);
  }

  @override
  bool shouldRepaint(covariant _AtomPainter old) => old.color != color;
}
