# WakeForce: the alarm that won't stop until you solve a JEE question

JEE aspirants lose their best study hours to the snooze button. WakeForce is an Android alarm that keeps ringing until you complete a **mission**: solve a real JEE Maths, Physics or Chemistry question, shake the phone, or photograph the notes you left on your desk.

I built it solo, from idea to a live MVP used by JEE students. I shipped it, interviewed daily users, and used the analytics to decide what to build next.

## The product

| Area | What it does |
|---|---|
| **Wake missions** | The alarm only stops when the mission is done: a JEE Maths, Physics or Chemistry question, a shake count, or a photo that matches your saved desk photo. |
| **Full-screen ringing** | The mission screen opens on its own at alarm time. There's no notification to tap first. |
| **Study routine** | You plan the day as study, break and personal blocks. Each block can ring like an alarm when it starts. |
| **Focus sessions** | Goal or open-ended timers with Do Not Disturb, a picker for apps to block, interruption counts, and adherence against the planned routine. |
| **Streaks and XP** | Every solved mission and focus minute earns XP, and streaks build a daily habit. |
| **Account sync** | With Google sign-in, streaks, alarms and routine come back after a reinstall or on a new phone. |
| **In-app feedback** | Students rate the app and leave a note, and the owner reads it all in an in-app inbox. |

## How it was built

- **Problem first:** it started from one problem JEE aspirants have, which is missing morning study.
- **MVP, then iteration:** it began as an alarm with a JEE question. Daily conversations with active users shaped every release after that.
- **Measured:** Firebase Analytics and GA4 track mission completions and cohort retention, and those numbers set the roadmap.
- **Distributed directly:** a signed APK was shared with students, without the Play Store. See [RELEASE.md](RELEASE.md).

## Tech stack

Flutter · Dart · Provider · Firebase Auth with Google Sign-In · Cloud Firestore · Firebase Analytics and GA4 · Android Alarm Manager · local notifications · sensors (shake) · on-device image similarity (photo mission)

```
lib/
  missions/   one file per wake mission (math, physics, chemistry, shake, photo)
  data/       JEE question banks
  models/     alarm, routine block, focus session, user stats
  services/   alarms, sound, vibration, focus/DND, cloud sync, analytics
  screens/    UI screens
test/         widget and unit tests
```

## Data and privacy

Firestore rules give each student read and write access to their own documents only. Feedback is create-only, and every other collection is denied by default. See [firestore.rules](firestore.rules).

## Run it

```bash
flutter pub get
flutter test
flutter run            # on an Android device or emulator
```

Release signing is covered in [RELEASE.md](RELEASE.md). The signing key is never committed.
