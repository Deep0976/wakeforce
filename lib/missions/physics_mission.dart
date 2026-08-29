import 'package:flutter/material.dart';

import '../data/jee_physics_questions.dart';
import '../models/alarm.dart';
import 'quiz_mission.dart';

class PhysicsMission extends StatelessWidget {
  final MissionDifficulty difficulty;
  final VoidCallback onComplete;

  const PhysicsMission({
    super.key,
    required this.difficulty,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return QuizMission(
      difficulty: difficulty,
      easyPool: jeePhysicsEasy,
      mediumPool: jeePhysicsMedium,
      hardPool: jeePhysicsHard,
      advancedPool: jeePhysicsAdvanced,
      onComplete: onComplete,
    );
  }
}
