import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/data/jee_chemistry_questions.dart';
import 'package:wake_mission_app/data/jee_math_questions.dart';
import 'package:wake_mission_app/data/jee_physics_questions.dart';
import 'package:wake_mission_app/data/quiz_question.dart';

/// Structural guarantees for the banks. A malformed question reaches a student
/// mid-alarm, so these are worth pinning even though the content itself still
/// needs a human eye.
void main() {
  final banks = <String, List<QuizQuestion>>{
    'physics easy': jeePhysicsEasy,
    'physics medium': jeePhysicsMedium,
    'physics hard': jeePhysicsHard,
    'maths easy': jeeMathEasy,
    'maths medium': jeeMathMedium,
    'maths hard': jeeMathHard,
    'chemistry easy': jeeChemistryEasy,
    'chemistry medium': jeeChemistryMedium,
    'chemistry hard': jeeChemistryHard,
  };

  banks.forEach((name, bank) {
    group(name, () {
      test('every question has 4 distinct options and a valid answer', () {
        for (final q in bank) {
          expect(q.options.length, 4, reason: q.prompt);
          expect(q.options.toSet().length, 4,
              reason: 'duplicate option in: ${q.prompt}');
          expect(q.correctIndex, inInclusiveRange(0, 3), reason: q.prompt);
          expect(q.options[q.correctIndex].trim(), isNotEmpty,
              reason: q.prompt);
        }
      });

      test('no duplicate prompts', () {
        final seen = <String>{};
        for (final q in bank) {
          final key = q.prompt.trim().toLowerCase();
          expect(seen.add(key), isTrue, reason: 'repeated: ${q.prompt}');
        }
      });
    });
  });

  test('physics is stocked to the same depth as the other subjects', () {
    // Physics used to hold 15 per tier against 75 elsewhere, so a daily
    // physics alarm ran the bank dry in about a week.
    for (final bank in [jeePhysicsEasy, jeePhysicsMedium, jeePhysicsHard]) {
      expect(bank.length, greaterThanOrEqualTo(100));
    }
  });

  test('answers are spread across positions, not parked at index 0', () {
    // The app shuffles at runtime, but a bank stored entirely at index 0
    // hides keying mistakes from anyone reading the data.
    final counts = <int, int>{};
    for (final q in [...jeePhysicsEasy, ...jeePhysicsMedium, ...jeePhysicsHard]) {
      counts[q.correctIndex] = (counts[q.correctIndex] ?? 0) + 1;
    }
    expect(counts.keys.length, 4);
    for (final n in counts.values) {
      expect(n, greaterThan(30));
    }
  });
}
