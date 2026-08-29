import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which apps Focus covers during a session, stored per account.
class ShieldProvider extends ChangeNotifier {
  /// The apps students actually lose time to. Seeded so the shield does
  /// something useful before anyone opens the picker.
  static const _defaultShielded = <String>[
    'com.instagram.android',
    'com.whatsapp',
    'com.google.android.youtube',
    'com.snapchat.android',
    'com.facebook.katana',
    'com.zhiliaoapp.musically', // TikTok
    'com.twitter.android',
    'com.reddit.frontpage',
    'in.mohalla.sharechat',
    'com.google.android.apps.youtube.music',
  ];

  String? _uid;
  Set<String> _shielded = {};

  Set<String> get shielded => Set.unmodifiable(_shielded);
  int get count => _shielded.length;

  String get _key => 'shieldedApps_$_uid';

  Future<void> loadForUser(String uid) async {
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key);
    // Defaults only until the student edits the list; an empty saved list is
    // a deliberate "shield nothing" and must not be overwritten.
    _shielded = {...(saved ?? _defaultShielded)};
    notifyListeners();
  }

  Future<void> reset() async {
    _shielded = {};
    _uid = null;
    notifyListeners();
  }

  Future<void> toggle(String packageName) async {
    if (!_shielded.remove(packageName)) _shielded.add(packageName);
    await _persist();
  }

  Future<void> setAll(Iterable<String> packages) async {
    _shielded = {...packages};
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _shielded.toList());
    notifyListeners();
  }
}
