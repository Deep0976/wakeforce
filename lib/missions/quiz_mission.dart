import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/quiz_question.dart';
import '../models/alarm.dart';
import '../services/auth_service.dart';
import '../services/mastered_questions_store.dart';
import '../theme/app_theme.dart';
import '../widgets/wake_card.dart';

/// Shared multiple-choice mission UI, used for both the JEE Math and
/// Inorganic Chemistry missions -- only the question pools differ.
///
/// Requires [questionCount] correct answers in a row before completing;
/// a wrong answer just re-serves a fresh random question at the same
/// position rather than resetting progress. Tapping an option only selects
/// it -- the answer is locked in via the Submit Answer button.
class QuizMission extends StatefulWidget {
  final MissionDifficulty difficulty;
  final List<QuizQuestion> easyPool;
  final List<QuizQuestion> mediumPool;
  final List<QuizQuestion> hardPool;
  final List<QuizQuestion> advancedPool;
  final VoidCallback onComplete;

  const QuizMission({
    super.key,
    required this.difficulty,
    required this.easyPool,
    required this.mediumPool,
    required this.hardPool,
    required this.advancedPool,
    required this.onComplete,
  });

  static int questionCountFor(MissionDifficulty difficulty) =>
      switch (difficulty) {
        MissionDifficulty.easy => 1,
        MissionDifficulty.medium => 2,
        MissionDifficulty.hard => 3,
        MissionDifficulty.advanced => 4,
      };

  @override
  State<QuizMission> createState() => _QuizMissionState();
}

class _QuizMissionState extends State<QuizMission> {
  final _random = Random();
  late final int _questionCount = QuizMission.questionCountFor(widget.difficulty);
  int _questionIndex = 0;
  late QuizQuestion _question;
  late List<String> _shuffledOptions;
  late int _correctShuffledIndex;
  int? _selectedIndex;
  bool _submitted = false;
  bool _wrong = false;
  bool _correct = false;

  String? _uid;
  Set<String> _mastered = const {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _uid = context.read<AuthService>().currentUser?.uid;
    _loadMasteredThenStart();
  }

  Future<void> _loadMasteredThenStart() async {
    final uid = _uid;
    if (uid != null) {
      _mastered = await MasteredQuestionsStore.load(uid);
    }
    if (!mounted) return;
    setState(() {
      _generateQuestion();
      _ready = true;
    });
  }

  List<QuizQuestion> get _pool => switch (widget.difficulty) {
        MissionDifficulty.easy => widget.easyPool,
        MissionDifficulty.medium => widget.mediumPool,
        MissionDifficulty.hard => widget.hardPool,
        MissionDifficulty.advanced => widget.advancedPool,
      };

  /// Prefers questions the student hasn't already answered correctly before
  /// -- once every question in the tier has been mastered, falls back to
  /// the full pool since something has to be shown.
  List<QuizQuestion> get _unmasteredPool {
    final unseen = _pool.where((q) => !_mastered.contains(q.prompt)).toList();
    return unseen.isNotEmpty ? unseen : _pool;
  }

  void _generateQuestion() {
    final pool = _unmasteredPool;
    _question = pool[_random.nextInt(pool.length)];
    final indices = List.generate(_question.options.length, (i) => i)
      ..shuffle(_random);
    _shuffledOptions = indices.map((i) => _question.options[i]).toList();
    _correctShuffledIndex = indices.indexOf(_question.correctIndex);
    _selectedIndex = null;
    _submitted = false;
    _wrong = false;
    _correct = false;
  }

  void _selectOption(int index) {
    if (_submitted) return;
    setState(() => _selectedIndex = index);
  }

  void _submit() {
    final selected = _selectedIndex;
    if (selected == null || _submitted) return;

    if (selected == _correctShuffledIndex) {
      final uid = _uid;
      if (uid != null) {
        _mastered = {..._mastered, _question.prompt};
        MasteredQuestionsStore.markMastered(uid, _question.prompt);
      }
      setState(() {
        _submitted = true;
        _correct = true;
        _questionIndex++;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_questionIndex >= _questionCount) {
          widget.onComplete();
          return;
        }
        setState(_generateQuestion);
      });
      return;
    }
    setState(() {
      _submitted = true;
      _wrong = true;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(_generateQuestion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wake;
    final theme = Theme.of(context);

    if (!_ready) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_questionCount > 1) ...[
            Text(
              'Question ${_questionIndex + 1} of $_questionCount',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.gapTight),
          ],
          WakeCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(
                _question.prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gap),
          ...List.generate(_shuffledOptions.length, (i) {
            final isSelected = _selectedIndex == i;
            final isWrongSelection = isSelected && _wrong;
            final isCorrectSelection = isSelected && _correct;

            final Color borderColor;
            final Color fill;
            final Color ink;
            if (isCorrectSelection) {
              borderColor = c.done;
              fill = c.done.withValues(alpha: 0.14);
              ink = c.done;
            } else if (isWrongSelection) {
              borderColor = theme.colorScheme.error;
              fill = theme.colorScheme.error.withValues(alpha: 0.12);
              ink = theme.colorScheme.error;
            } else if (isSelected) {
              borderColor = c.accent;
              fill = c.accent.withValues(alpha: 0.12);
              ink = c.textPrimary;
            } else {
              borderColor = c.divider;
              fill = c.card;
              ink = c.textPrimary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.gapTight),
              child: Material(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  onTap: () => _selectOption(i),
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: kMinHitTarget + 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.cardTight,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // A/B/C/D marker keeps the options scannable.
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.16),
                            borderRadius:
                                BorderRadius.circular(AppRadius.chip - 4),
                          ),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: numberStyle(fontSize: 10, color: ink),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.gap),
                        Expanded(
                          child: Text(
                            _shuffledOptions[i],
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_wrong) ...[
            const SizedBox(height: 2),
            Text(
              'Wrong answer — try again',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.gapTight),
          FilledButton(
            onPressed: _selectedIndex == null || _submitted ? null : _submit,
            child: const Text('Submit answer'),
          ),
        ],
      ),
    );
  }
}
