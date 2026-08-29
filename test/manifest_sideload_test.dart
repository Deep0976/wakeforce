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
}
