import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// What a round of feedback is about. Round one asks about setting the first
/// alarm, because that is the only thing the student has done yet; every
/// round after asks about living with the app.
class FeedbackTopic {
  final String label;
  final String question;
  final List<String> reasons;
  final List<String> starLabels;

  const FeedbackTopic({
    required this.label,
    required this.question,
    required this.reasons,
    required this.starLabels,
  });

  String labelForStars(int stars) =>
      stars < 1 ? '' : starLabels[stars.clamp(1, 5) - 1];

  static const firstWake = FeedbackTopic(
    label: 'YOUR FIRST WAKE-UP',
    question: 'WHAT WAS HARDEST?',
    reasons: [
      'Setting it up',
      'Choosing a mission',
      'Permissions',
      'Waking up to it',
      'Solving the question',
      'Nothing, it went fine',
    ],
    starLabels: [
      'It did not work for me',
      'Rough — I nearly gave up',
      'OK — a few things got in the way',
      'Good — one thing tripped me up',
      'It did exactly what I wanted',
    ],
  );

  static const usage = FeedbackTopic(
    label: 'USING WAKEFORCE',
    question: 'WHAT COULD BE BETTER?',
    reasons: [
      'Waking up on time',
      'The questions',
      'Routine blocks',
      'Focus mode',
      'Battery or permissions',
      'Nothing, it is working',
    ],
    starLabels: [
      'Not working for me',
      'More annoying than useful',
      'OK — but it could be better',
      'Good — one thing bugs me',
      'It is doing exactly what I need',
    ],
  );
}

/// Decides when to ask a student what they think, and files the answer.
///
/// Counted in solved alarms, not days. The first ask waits until a student
/// has actually been woken by the app and solved the mission -- by then they
/// have set it up, lived with it overnight and used it, so the answer is
/// worth something. Asking at setup only ever rates the setup form.
///
/// After that it is a loop, and the gap widens each round -- 4-8, then 8-12,
/// then 12-16 -- so someone who keeps using the app keeps being asked without
/// being pestered. The gap is randomised inside its band so a whole class is
/// not prompted the same morning.
class FeedbackPrompt {
  FeedbackPrompt._();

  static const _roundKey = 'feedbackRound';
  static const _nextKey = 'feedbackNextAtSolved';
  static const _offKey = 'feedbackOff';
  static const _collection = 'feedback';

  static const gapStep = 4;
  static const gapSpread = 5;

  /// Whose accounts may read what students wrote. Two, because the Firebase
  /// console login and the account the app is actually signed into are not
  /// the same address -- both belong to the same person. Everyone else is
  /// refused by the Firestore rules; this list only decides whether the
  /// Settings row is worth drawing, and must be kept in step with them.
  static const ownerEmails = {
    'v.notebooklm@gmail.com',
    'deepagrawal567@gmail.com',
  };

  static bool get isOwner {
    final email = AuthService.instance.currentUser?.email.toLowerCase();
    return email != null && ownerEmails.contains(email);
  }

  /// Every answer, newest first. Readable only by [ownerEmails].
  static Stream<QuerySnapshot<Map<String, dynamic>>> inbox() =>
      FirebaseFirestore.instance
          .collection(_collection)
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .snapshots();

  static Future<bool> get _off async =>
      await SharedPreferencesAsync().getBool(_offKey) ?? false;

  static Future<int> get round async =>
      await SharedPreferencesAsync().getInt(_roundKey) ?? 0;

  /// The first ask lands on the first solved alarm.
  static const firstAt = 1;

  /// Owed once enough alarms have been solved. [solvedAlarms] is the lifetime
  /// number of missions solved.
  static Future<bool> dueAfterMission(int solvedAlarms) async {
    if (await _off) return false;
    final next = await SharedPreferencesAsync().getInt(_nextKey) ?? firstAt;
    return solvedAlarms >= next;
  }

  static Future<FeedbackTopic> topic() async =>
      await round == 0 ? FeedbackTopic.firstWake : FeedbackTopic.usage;

  /// Closes a round and sets when the next one falls due. Called after both
  /// buttons -- skipping and answering both mean "not again for a while".
  static Future<void> defer(int solvedAlarms, {Random? random}) async {
    final prefs = SharedPreferencesAsync();
    final next = (await prefs.getInt(_roundKey) ?? 0) + 1;
    final gap = gapStep * next + (random ?? Random()).nextInt(gapSpread);
    await prefs.setInt(_roundKey, next);
    await prefs.setInt(_nextKey, solvedAlarms + gap);
  }

  /// The student asked not to be asked again. Honoured for good.
  static Future<void> disable() =>
      SharedPreferencesAsync().setBool(_offKey, true);

  /// Answers that could not be sent yet, oldest first.
  static const _pendingKey = 'feedbackPending';

  /// Keeps a failed answer instead of dropping it. Capped, because a student
  /// offline for a fortnight should not carry an unbounded backlog.
  static Future<void> _queue(Map<String, dynamic> doc) async {
    final prefs = SharedPreferencesAsync();
    final queued = await prefs.getStringList(_pendingKey) ?? [];
    queued.add(jsonEncode(doc));
    await prefs.setStringList(
      _pendingKey,
      queued.length > 5 ? queued.sublist(queued.length - 5) : queued,
    );
  }

  /// Sends anything an earlier attempt could not. Cheap and safe to call on
  /// every app open -- it returns immediately when the queue is empty.
  ///
  /// An answer written while signed out has no uid; it is stamped with
  /// whoever is signed in when it finally goes. One belonging to a different
  /// account stays queued rather than being filed under the wrong student.
  static Future<void> flushPending() async {
    if (kIsWeb) return;
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final prefs = SharedPreferencesAsync();
    final queued = await prefs.getStringList(_pendingKey) ?? [];
    if (queued.isEmpty) return;

    final unsent = <String>[];
    for (final entry in queued) {
      try {
        final doc = jsonDecode(entry) as Map<String, dynamic>;
        final owner = doc['uid'];
        if (owner != null && owner != user.uid) {
          unsent.add(entry);
          continue;
        }
        doc['uid'] = user.uid;
        await FirebaseFirestore.instance.collection(_collection).add({
          ...doc,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[WakeForce] feedback still unsent, kept for later: $e');
        unsent.add(entry);
      }
    }
    await prefs.setStringList(_pendingKey, unsent);
  }

  /// Files one answer and closes the round.
  ///
  /// Fails soft -- a student with no connection must not be shown an error
  /// for trying to be helpful -- but never silently: an answer that cannot be
  /// sent is queued and goes out on a later launch. Losing it outright is
  /// worse than any error dialog, because the student believes they were
  /// heard.
  static Future<void> submit({
    required int stars,
    required List<String> reasons,
    required String comment,
    required int solvedAlarms,
    Map<String, dynamic>? context,
  }) async {
    final asked = await round;
    await defer(solvedAlarms);
    if (kIsWeb) return;

    // Reading the signed-in account can throw outright when Firebase is not
    // up. Treat that as signed out and queue, rather than letting it escape
    // and strand the form on "Sending...".
    AppUser? user;
    try {
      user = AuthService.instance.currentUser;
    } catch (e) {
      debugPrint('[WakeForce] no auth for feedback, queued: $e');
    }

    // Mirrored to Analytics so the star average and answer rate show up in
    // the GA4 dashboards without opening Firestore. The comment stays out of
    // it -- free text belongs in the document, not in an event parameter.
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'feedback_submitted',
        parameters: {
          'stars': stars,
          'round': asked + 1,
          'topic': asked == 0 ? 'first_wake' : 'usage',
          'has_comment': comment.trim().isEmpty ? 'no' : 'yes',
        },
      );
    } catch (e) {
      debugPrint('[WakeForce] could not log feedback event: $e');
    }

    // One document per answer, not per student: the loop asks more than once,
    // and the second answer must not erase the first.
    final doc = <String, dynamic>{
      'uid': ?user?.uid,
      'stars': stars,
      'reasons': reasons,
      'comment': comment.trim(),
      'name': ?user?.displayName,
      'email': ?user?.email,
      'round': asked + 1,
      'topic': asked == 0 ? 'first_wake' : 'usage',
      'solvedAlarms': solvedAlarms,
      'context': ?context,
      'answeredAt': DateTime.now().toIso8601String(),
    };

    // Signed out, so the rules would refuse it. Keep it and send it when they
    // are back rather than pretending it went.
    if (user == null) {
      await _queue(doc);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection(_collection).add({
        ...doc,
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[WakeForce] could not send feedback, queued: $e');
      await _queue(doc);
    }
  }
}
