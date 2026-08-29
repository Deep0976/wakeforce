import 'package:flutter/material.dart';

import '../data/jee_chemistry_questions.dart';
import '../models/alarm.dart';
import 'quiz_mission.dart';

class ChemistryMission extends StatelessWidget {
  final MissionDifficulty difficulty;
  final VoidCallback onComplete;

  const ChemistryMission({
    super.key,
    required this.difficulty,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return QuizMission(
      difficulty: difficulty,
      easyPool: jeeChemistryEasy,
      mediumPool: jeeChemistryMedium,
      hardPool: jeeChemistryHard,
      advancedPool: jeeChemistryAdvanced,
      onComplete: onComplete,
    );
  }
}
