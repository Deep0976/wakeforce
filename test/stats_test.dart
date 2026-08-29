import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/user_stats.dart';

void main() {
  const week = '2026-08-10';

  test('preferredMission is none until a mission is completed', () {
    expect(const UserStats(weekStartIso: week).preferredMission, 'none');
  });

  test('preferredMission picks the most-used type, ties break deterministically',
      () {
    expect(
      const UserStats(weekStartIso: week, mathSolved: 1, photoSolved: 3)
          .preferredMission,
      'photo',
    );
    expect(
      const UserStats(weekStartIso: week, shakeSolved: 5, chemistrySolved: 2)
          .preferredMission,
      'shake',
    );
    // Tie: map-literal order wins so the value doesn't flip between sessions.
    expect(
      const UserStats(weekStartIso: week, mathSolved: 2, chemistrySolved: 2)
          .preferredMission,
      'math',
    );
  });

  test('streakBand buckets rather than reporting raw numbers', () {
    expect(const UserStats(weekStartIso: week).streakBand, '0');
    expect(
      const UserStats(weekStartIso: week, currentStreak: 2).streakBand,
      '1-2',
    );
    expect(
      const UserStats(weekStartIso: week, currentStreak: 7).streakBand,
      '7-13',
    );
    expect(
      const UserStats(weekStartIso: week, currentStreak: 40).streakBand,
      '14+',
    );
  });

  test('a streak survives today and yesterday, dies otherwise', () {
    const stats = UserStats(
      weekStartIso: week,
      currentStreak: 5,
      bestStreak: 5,
      lastCompletionDateIso: '2026-08-09',
    );
    // Completed today.
    expect(stats.withStreakDecay('2026-08-09', '2026-08-08').currentStreak, 5);
    // Completed yesterday -- still alive, they can extend it today.
    expect(stats.withStreakDecay('2026-08-10', '2026-08-09').currentStreak, 5);
    // Lapsed: this is the case that used to keep showing a stale "5".
    final decayed = stats.withStreakDecay('2026-08-13', '2026-08-12');
    expect(decayed.currentStreak, 0);
    expect(decayed.bestStreak, 5, reason: 'best streak is an all-time record');
  });

  test('new counters default to zero on stats saved before they existed', () {
    final old = UserStats.fromJson({
      'currentStreak': 3,
      'mathSolved': 4,
      'weekStartIso': week,
    });
    expect(old.shakeSolved, 0);
    expect(old.photoSolved, 0);
    expect(old.preferredMission, 'math');
  });
}
