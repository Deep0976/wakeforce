import 'package:flutter/material.dart';

import '../data/jee_math_questions.dart';
import '../models/alarm.dart';
import 'quiz_mission.dart';

class MathMission extends StatelessWidget {
  final MissionDifficulty difficulty;
  final VoidCallback onComplete;

  const MathMission({
    super.key,
    required this.difficulty,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return QuizMission(
      difficulty: difficulty,
      easyPool: jeeMathEasy,
      mediumPool: jeeMathMedium,
      hardPool: jeeMathHard,
      advancedPool: jeeMathAdvanced,
      onComplete: onComplete,
    );
  }
}
