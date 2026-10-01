import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Keeps a student's alarms and routine blocks with their account rather than
/// their install.
///
/// Streak and XP already survive a reinstall through [StatsCloudSync]; the
/// things they actually configured did not. A student who changes phone, or
/// who is asked to uninstall because the signing key changed, got their
/// numbers back and an empty app -- which is the wrong half.
///
/// Rows are stored exactly as the local repositories already serialise them:
/// a list of JSON strings. Nothing here needs to understand an alarm.
///
/// Every call fails soft. Waking up must never depend on the network.
class SetupCloudSync {
  SetupCloudSync._();
  static final SetupCloudSync instance = SetupCloudSync._();

  static const alarmsCollection = 'userAlarms';
  static const routineCollection = 'userRoutine';

  static const _field = 'items';

  /// The saved list, or null when there isn't one or it can't be read. Null
  /// means "don't know", never "empty" -- the caller must not treat a failed
  /// read as a student with no alarms.
  Future<List<String>?> fetch(String collection, String uid) async {
    if (kIsWeb) return null;
    try {
      final snap =
          await FirebaseFirestore.instance.collection(collection).doc(uid).get();
      final items = snap.data()?[_field];
      if (items is! List) return null;
      return items.whereType<String>().toList();
    } catch (e) {
      debugPrint('[WakeForce] could not read cloud $collection: $e');
      return null;
    }
  }

  Future<void> push(String collection, String uid, List<String> items) async {
    if (kIsWeb) return;
    try {
      await FirebaseFirestore.instance.collection(collection).doc(uid).set({
        _field: items,
        // Server time, not the phone's: a device with a wrong clock must not
        // win by claiming to be newer.
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[WakeForce] could not write cloud $collection: $e');
    }
  }
}
