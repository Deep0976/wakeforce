# Releasing WakeForce

## One-time: create the signing key

The APK students install is identified by the key that signed it. Android will
not install an update signed by a different key -- the student has to uninstall
first, which wipes their alarms and routine blocks (streak and XP survive, they
sync to the account). So this key is created **once** and never lost.

The default Flutter setup signs release builds with the debug key, which lives
at `~/.android/debug.keystore` on one machine and triggers Play Protect
warnings. That is fine for testing on your own phone and must never reach a
student.

Generate the key (pick your own password, and keep it somewhere you will still
have in five years):

```bash
keytool -genkey -v -keystore ~/wakeforce-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias wakeforce
```

Then create `android/key.properties` from `android/key.properties.example`:

```properties
storePassword=<the password you just chose>
keyPassword=<same, unless you set a separate key password>
keyAlias=wakeforce
storeFile=/Users/you/wakeforce-upload.jks
```

`key.properties` and `*.jks` are gitignored and must stay that way.

**Back up both the `.jks` file and the password**, somewhere that survives this
laptop. Losing either means you can never update the app for anyone who already
has it.

## Build the APK for students

```bash
flutter build apk --release
```

One universal APK covering every device, at
`build/app/outputs/flutter-apk/app-release.apk`. Do not use `--split-per-abi`
for direct distribution -- students would have to know their own CPU.

Check it is not debug-signed: the build prints a loud
`WakeForce: release build is DEBUG-SIGNED` warning when `key.properties` is
missing. If you see that line, the APK is not fit to send.

## Before each release

- `flutter analyze` clean and `flutter test` green.
- Bump `version:` in `pubspec.yaml`. Android refuses to install an APK whose
  versionCode is lower than the installed one, and equal codes make it
  ambiguous which build a student actually has.
- If `firestore.rules` changed: `firebase deploy --only firestore:rules`.
  Cloud sync fails soft, so unpushed rules look like nothing happening rather
  than an error.
- Test one alarm and one routine block on a real phone, locked and untouched.
  This is the one thing the test suite cannot tell you.

## Play Store, later

Play App Signing re-signs uploads with a key Google holds, so the key above
becomes the *upload* key. You can ask Google to use your existing key instead,
which is the only way students who sideloaded can update in place rather than
reinstalling.
