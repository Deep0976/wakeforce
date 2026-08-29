import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../models/alarm.dart';
import '../models/mission_type.dart';
import '../models/focus_session.dart';
import '../models/user_stats.dart';
import 'stats_repository.dart';

const _xpPerLevel = 250;

const _levelTitles = [
  'Sleepy Starter',
  'Early Riser',
  'Dawn Patrol',
  'Momentum Builder',
  'Discipline Seeker',
  'Habit Former',
  'Focused Aspirant',
  'Consistency Champion',
  'Relentless Grinder',
  'Peak Performer',
  'Unstoppable',
  'Legend',
];

int xpAwardFor(MissionDifficulty difficulty) => switch (difficulty) {
      MissionDifficulty.easy => 20,
      MissionDifficulty.medium => 40,
      MissionDifficulty.hard => 60,
      MissionDifficulty.advanced => 90,
    };

class StatsProvider extends ChangeNotifier {
  StatsRepository? _repository;

  /// Resolved lazily: a field initializer would touch Firebase the moment
  /// this provider is constructed, which makes the whole widget tree
  /// unbuildable in tests where Firebase.initializeApp hasn't run.
  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  UserStats _stats = UserStats(
    weekStartIso: StatsRepository.isoDate(StatsRepository.mondayOf(DateTime.now())),
  );
  bool _loaded = false;

  UserStats get stats => _stats;
  bool get loaded => _loaded;

  int get level => _stats.totalXp ~/ _xpPerLevel + 1;
  int get xpIntoLevel => _stats.totalXp % _xpPerLevel;
  int get xpPerLevel => _xpPerLevel;
  String get levelTitle =>
      _levelTitles[(level - 1).clamp(0, _levelTitles.length - 1)];

  /// Null when no alarm has rung this week.
  ///
  /// A rate over zero attempts is undefined, not perfect. Returning 1.0 meant
  /// a student who had never been woken saw "100% success rate" beside "0
  /// alarms rang" -- a flattering number with nothing behind it.
  double? get successRateThisWeek {
    if (_stats.alarmsAttemptedThisWeek == 0) return null;
    return (_stats.alarmsCompletedThisWeek / _stats.alarmsAttemptedThisWeek)
        .clamp(0.0, 1.0);
  }

  /// Loads the signed-in user's streak/XP -- a different account signing in
  /// on this device must start from its own stats, not inherit whichever
  /// account was last active.
  Future<void> loadForUser(String uid) async {
    _repository = StatsRepository(uid);
    _stats = await _repository!.loadStats();
    _rolloverWeekIfNeeded();
    _decayStreakIfBroken();
    _loaded = true;
    notifyListeners();
    await _repository!.saveStats(_stats);
    await _syncAnalyticsUserProperties();
  }

  /// Called on sign-out: resets in-memory stats to a blank slate so a
  /// different account signing in on this device doesn't briefly see the
  /// previous account's streak/XP before its own stats load.
  Future<void> reset() async {
    _stats = UserStats(
      weekStartIso: StatsRepository.isoDate(StatsRepository.mondayOf(DateTime.now())),
    );
    _loaded = false;
    _repository = null;
    notifyListeners();
    // Otherwise a second Google account signing in on this device would
    // inherit the previous student's analytics segment.
    await _analytics.setUserProperty(name: 'preferred_mission', value: null);
    await _analytics.setUserProperty(name: 'streak_band', value: null);
  }

  /// Call when a mission's ringing screen opens, before it's known whether
  /// the mission will actually be completed (used for the weekly success
  /// rate denominator).
  Future<void> recordMissionAttempted() async {
    _rolloverWeekIfNeeded();
    _stats = _stats.copyWith(
      alarmsAttemptedThisWeek: _stats.alarmsAttemptedThisWeek + 1,
    );
    await _persist();
  }

  /// Call when a mission is actually solved. Returns the XP just earned so
  /// the caller can show "+XX XP".
  Future<int> recordMissionCompleted(
    MissionType missionType,
    MissionDifficulty difficulty,
  ) async {
    _rolloverWeekIfNeeded();

    final today = DateTime.now();
    final todayIso = StatsRepository.isoDate(today);
    final yesterdayIso =
        StatsRepository.isoDate(today.subtract(const Duration(days: 1)));

    int newStreak;
    if (_stats.lastCompletionDateIso == todayIso) {
      newStreak = _stats.currentStreak;
    } else if (_stats.lastCompletionDateIso == yesterdayIso) {
      newStreak = _stats.currentStreak + 1;
    } else {
      newStreak = 1;
    }

    final award = xpAwardFor(difficulty);

    _stats = _stats.copyWith(
      currentStreak: newStreak,
      bestStreak: newStreak > _stats.bestStreak ? newStreak : _stats.bestStreak,
      lastCompletionDateIso: todayIso,
      totalXp: _stats.totalXp + award,
      mathSolved: missionType == MissionType.math
          ? _stats.mathSolved + 1
          : _stats.mathSolved,
      chemistrySolved: missionType == MissionType.typing
          ? _stats.chemistrySolved + 1
          : _stats.chemistrySolved,
      physicsSolved: missionType == MissionType.physics
          ? _stats.physicsSolved + 1
          : _stats.physicsSolved,
      shakeSolved: missionType == MissionType.shake
          ? _stats.shakeSolved + 1
          : _stats.shakeSolved,
      photoSolved: missionType == MissionType.photo
          ? _stats.photoSolved + 1
          : _stats.photoSolved,
      alarmsCompletedThisWeek: _stats.alarmsCompletedThisWeek + 1,
    );
    await _persist();
    return award;
  }

  /// Banks a finished focus sitting. Focus XP feeds the same level track as
  /// mission XP -- the completion screen promises "+N XP", so it has to
  /// actually move the student's total.
  Future<int> recordFocusSession(FocusSession session) async {
    final award = session.xpEarned;
    _stats = _stats.copyWith(totalXp: _stats.totalXp + award);
    await _persist();
    return award;
  }

  void _rolloverWeekIfNeeded() {
    final currentWeekStart =
        StatsRepository.isoDate(StatsRepository.mondayOf(DateTime.now()));
    if (_stats.weekStartIso != currentWeekStart) {
      _stats = _stats.copyWith(
        weekStartIso: currentWeekStart,
        alarmsCompletedThisWeek: 0,
        alarmsAttemptedThisWeek: 0,
      );
    }
  }

  /// Home/Progress read currentStreak straight off the stored stats, and
  /// recordMissionCompleted is the only other place that recomputes it -- so
  /// without this a student who broke a 5-day streak kept seeing "5" until
  /// their next completion silently reset it to 1.
  void _decayStreakIfBroken() {
    final today = DateTime.now();
    _stats = _stats.withStreakDecay(
      StatsRepository.isoDate(today),
      StatsRepository.isoDate(today.subtract(const Duration(days: 1))),
    );
  }

  /// User-scoped, not event parameters: GA4's retention and cohort reports
  /// can only segment on user scope, which is why "which mission do the
  /// students who stuck around actually use" isn't answerable from the
  /// mission_type event parameter alone.
  Future<void> _syncAnalyticsUserProperties() async {
    // Fail soft. Reporting is a nice-to-have; the student's streak and XP are
    // not. Letting an analytics failure propagate out of loadForUser would
    // abandon the whole load and leave Progress blank.
    try {
      await _analytics.setUserProperty(
        name: 'preferred_mission',
        value: _stats.preferredMission,
      );
      await _analytics.setUserProperty(
        name: 'streak_band',
        value: _stats.streakBand,
      );
    } catch (e) {
      debugPrint('[WakeForce] analytics user properties skipped: $e');
    }
  }

  Future<void> _persist() async {
    await _repository?.saveStats(_stats);
    await _syncAnalyticsUserProperties();
    notifyListeners();
  }
}
