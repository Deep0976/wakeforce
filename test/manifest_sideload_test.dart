import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Google's Enhanced Fraud Protection (live in India) hard-blocks *sideloaded*
/// apps that declare any of these four permissions. There is no "install
/// anyway" on that dialog, so declaring one makes the APK impossible to share
/// with students outside the Play Store.
///
/// Usage access and the overlay permission are deliberately NOT listed: they
/// power app shielding, they are not on Google's published list, and the app
/// ships with them by choice.
void main() {
  test('the manifest declares no permission that blocks sideloading', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    const blockers = [
      // Google's Enhanced Fraud Protection names these four outright.
      'BIND_NOTIFICATION_LISTENER_SERVICE',
      'BIND_ACCESSIBILITY_SERVICE',
      'android.permission.READ_SMS',
      'android.permission.RECEIVE_SMS',
    ];

    for (final permission in blockers) {
      expect(manifest.contains(permission), isFalse,
          reason: '$permission makes the APK unsideloadable — Play Protect '
              'blocks it outright with no way past the dialog');
    }
  });

/// The native rings that launch the ringing screen are ours to restore --
/// Android clears every AlarmManager entry on reboot and on an app update, and
/// the alarm plugin's own reboot receiver only brings back its Dart alarms.
/// Lose this declaration and a phone that was off overnight goes quiet until
/// the student happens to open the app.
  test('a boot receiver is declared, exported, and hears both wipe events', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    final receiver = RegExp(
      r'<receiver[^>]*android:name="\.BootReceiver"(.*?)</receiver>',
      dotAll: true,
    ).firstMatch(manifest);

    expect(receiver, isNotNull,
        reason: 'BootReceiver is what re-arms the native rings after a '
            'reboot; without it they are simply gone');
    final block = receiver!.group(0)!;

    // A manifest receiver only hears a system broadcast when it is exported.
    expect(block.contains('android:exported="true"'), isTrue);
    expect(block.contains('android.intent.action.BOOT_COMPLETED'), isTrue);
    expect(block.contains('android.intent.action.MY_PACKAGE_REPLACED'), isTrue);
    expect(manifest.contains('android.permission.RECEIVE_BOOT_COMPLETED'), isTrue);
  });

  test('DND access is declared, or Focus cannot ask for it', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // Settings > Do Not Disturb access lists only apps that declare this.
    // Undeclared, WakeForce simply is not on that screen, so the student
    // cannot grant DND and Focus mode's toggle is stuck on ALLOW forever.
    expect(manifest.contains('android.permission.ACCESS_NOTIFICATION_POLICY'),
        isTrue);
  });
}
