import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';

class AlarmRepository {
  static const _legacyKey = 'alarms';

  final String uid;
  const AlarmRepository(this.uid);

  String get _storageKey => 'alarms_$uid';

  /// One-time migration for data saved before alarms were scoped per
  /// account: adopts the old shared blob into whichever uid loads first
  /// (the account already in use), then removes it so a different account
  /// signing in later on this device doesn't also inherit it.
  Future<void> _migrateLegacyIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_legacyKey);
    if (legacy == null) return;
    if (prefs.getStringList(_storageKey) == null) {
      await prefs.setStringList(_storageKey, legacy);
    }
    await prefs.remove(_legacyKey);
  }

  Future<List<Alarm>> loadAlarms() async {
    await _migrateLegacyIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    return raw
        .map((e) => Alarm.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = alarms.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
  }
}
