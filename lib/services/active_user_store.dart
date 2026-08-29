import 'package:shared_preferences/shared_preferences.dart';

/// Persists which Firebase UID is currently signed in, in a slot the
/// background alarm isolate can read -- that isolate has no access to
/// AuthService, but still needs to know whose alarms to look up when
/// re-arming a repeating alarm after it fires.
class ActiveUserStore {
  ActiveUserStore._();
  static const _key = 'activeUserId';

  static Future<void> set(String? uid) async {
    final prefs = SharedPreferencesAsync();
    if (uid == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, uid);
    }
  }

  static Future<String?> get() => SharedPreferencesAsync().getString(_key);
}
