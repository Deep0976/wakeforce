import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_mission_app/services/settings_provider.dart';

/// A student installing the APK must land in light mode, whatever their phone
/// is set to. They can switch afterwards; the first impression is light.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a fresh install defaults to light, not system or dark', () async {
    SharedPreferences.setMockInitialValues({}); // nothing stored yet
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.themeMode, ThemeMode.light);
  });

  test('a stored choice still wins over the default', () async {
    SharedPreferences.setMockInitialValues({'flutter.themeMode': 'dark'});
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.themeMode, ThemeMode.dark,
        reason: 'a student who picked dark must keep it');
  });

  test('an unrecognised stored value falls back to light', () async {
    SharedPreferences.setMockInitialValues({'flutter.themeMode': 'nonsense'});
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.themeMode, ThemeMode.light);
  });
}
