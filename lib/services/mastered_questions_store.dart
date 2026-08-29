import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which quiz question prompts a student has already answered
/// correctly, per account, so the mission never re-serves a question
/// they've already gotten right -- only fresh/unseen-correct questions are
/// picked until the whole tier is exhausted.
class MasteredQuestionsStore {
  MasteredQuestionsStore._();

  static String _key(String uid) => 'masteredQuestions_$uid';

  static Future<Set<String>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(uid)) ?? const []).toSet();
  }

  static Future<void> markMastered(String uid, String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(uid);
    final current = prefs.getStringList(key) ?? [];
    if (!current.contains(prompt)) {
      current.add(prompt);
      await prefs.setStringList(key, current);
    }
  }
}
