import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_stats.dart';

/// Keeps a student's streak and XP with their account rather than their
/// install.
///
/// This exists because the app is moving from a sideloaded APK to the Play
/// Store, which changes the signing key and forces every student to uninstall
/// and reinstall. Local storage does not survive that. Stats synced here come
/// back when they sign in again -- on the new build, or on a new phone.
///
/// Every call fails soft. A student with no connection must still be able to
/// wake up and solve a mission; syncing is a convenience, never a gate.
class StatsCloudSync {
  StatsCloudSync._();
  static final StatsCloudSync instance = StatsCloudSync._();

  static const _collection = 'userStats';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection(_collection).doc(uid);

  /// Reads the cloud copy, or null when there isn't one or it can't be read.
  Future<UserStats?> fetch(String uid) async {
    if (kIsWeb) return null;
    try {
      final snap = await _doc(uid).get();
      final data = snap.data();
      if (data == null) return null;
      return UserStats.fromJson(data);
    } catch (e) {
      debugPrint('[WakeForce] could not read cloud stats: $e');
      return null;
    }
  }

  Future<void> push(String uid, UserStats stats) async {
    if (kIsWeb) return;
    try {
      await _doc(uid).set({
        ...stats.toJson(),
        // Server time, not the phone's: a device with a wrong clock must not
        // win a merge just by claiming to be newer.
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[WakeForce] could not write cloud stats: $e');
    }
  }

  /// Combines a local and a cloud copy without ever losing progress.
  ///
  /// Counters that only ever go up take the larger of the two, so a sync in
  /// either direction is safe and neither side can roll the other back. The
  /// streak follows whichever copy completed a mission most recently, because
  /// a streak is a statement about a date, not a number to be maximised: the
  /// phone that solved today's alarm holds the truth.
  static UserStats merge(UserStats local, UserStats cloud) {
    int larger(int a, int b) => a > b ? a : b;

    final localDate = local.lastCompletionDateIso ?? '';
    final cloudDate = cloud.lastCompletionDateIso ?? '';
    final localIsNewer = localDate.compareTo(cloudDate) >= 0;
    final recent = localIsNewer ? local : cloud;

    // The weekly counters belong to a week. Carrying last week's numbers into
    // this week would inflate "alarms solved this week", so the newer week
    // wins outright rather than being maxed against the older one.
    final sameWeek = local.weekStartIso == cloud.weekStartIso;
    final newerWeek =
        local.weekStartIso.compareTo(cloud.weekStartIso) >= 0 ? local : cloud;

    return UserStats(
      currentStreak: recent.currentStreak,
      lastCompletionDateIso: recent.lastCompletionDateIso,
      bestStreak: larger(local.bestStreak, cloud.bestStreak),
      totalXp: larger(local.totalXp, cloud.totalXp),
      mathSolved: larger(local.mathSolved, cloud.mathSolved),
      chemistrySolved: larger(local.chemistrySolved, cloud.chemistrySolved),
      physicsSolved: larger(local.physicsSolved, cloud.physicsSolved),
      shakeSolved: larger(local.shakeSolved, cloud.shakeSolved),
      photoSolved: larger(local.photoSolved, cloud.photoSolved),
      weekStartIso: newerWeek.weekStartIso,
      alarmsCompletedThisWeek: sameWeek
          ? larger(local.alarmsCompletedThisWeek, cloud.alarmsCompletedThisWeek)
          : newerWeek.alarmsCompletedThisWeek,
      alarmsAttemptedThisWeek: sameWeek
          ? larger(local.alarmsAttemptedThisWeek, cloud.alarmsAttemptedThisWeek)
          : newerWeek.alarmsAttemptedThisWeek,
    );
  }
}
