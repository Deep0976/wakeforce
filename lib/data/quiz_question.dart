class QuizQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}
