import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import 'setup_cloud_sync.dart';

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

  /// Local first, cloud only to fill an empty install.
  ///
  /// A fresh install -- new phone, or the reinstall a changed signing key
  /// forces -- has no local alarms, and that is the one case where the copy
  /// kept with the account is unambiguously the right answer. Once there is
  /// anything local, local wins: it is what the student is looking at.
  ///
  /// ponytail: last-write-wins across two phones in active use is not
  /// handled -- the second phone keeps its own copy. Stamp each save with a
  /// local timestamp and compare against the cloud one if that ever matters.
  Future<List<Alarm>> loadAlarms() async {
    await _migrateLegacyIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getStringList(_storageKey) ?? [];

    if (raw.isEmpty) {
      final cloud =
          await SetupCloudSync.instance.fetch(SetupCloudSync.alarmsCollection, uid);
      if (cloud != null && cloud.isNotEmpty) {
        raw = cloud;
        await prefs.setStringList(_storageKey, raw);
      }
    }

    return raw
        .map((e) => Alarm.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAlarms(List<Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = alarms.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_storageKey, raw);
    await SetupCloudSync.instance
        .push(SetupCloudSync.alarmsCollection, uid, raw);
  }
}
