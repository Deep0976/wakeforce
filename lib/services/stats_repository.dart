import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_stats.dart';

class StatsRepository {
  static const _legacyKey = 'userStats';

  final String uid;
  const StatsRepository(this.uid);

  String get _storageKey => 'userStats_$uid';

  /// One-time migration for data saved before stats were scoped per
  /// account: adopts the old shared blob into whichever uid loads first
  /// (the account already in use), then removes it so a different account
  /// signing in later on this device doesn't also inherit it.
  Future<void> _migrateLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyKey);
    if (legacy == null) return;
    if (prefs.getString(_storageKey) == null) {
      await prefs.setString(_storageKey, legacy);
    }
    await prefs.remove(_legacyKey);
  }

  Future<UserStats> loadStats() async {
    await _migrateLegacyIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return UserStats(weekStartIso: isoDate(mondayOf(DateTime.now())));
    }
    return UserStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveStats(UserStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(stats.toJson()));
  }

  static DateTime mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));

  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
