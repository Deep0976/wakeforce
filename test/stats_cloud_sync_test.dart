import 'package:flutter_test/flutter_test.dart';
import 'package:wake_mission_app/models/user_stats.dart';
import 'package:wake_mission_app/services/stats_cloud_sync.dart';

/// The merge that decides whether a student keeps their streak through the
/// move to the Play Store. Getting this wrong silently erases months of work,
/// so every direction is pinned.
void main() {
  UserStats stats({
    int streak = 0,
    String? last,
    int best = 0,
    int xp = 0,
    int maths = 0,
    String week = '2026-08-24',
    int done = 0,
    int rang = 0,
  }) =>
      UserStats(
        currentStreak: streak,
        lastCompletionDateIso: last,
        bestStreak: best,
        totalXp: xp,
        mathSolved: maths,
        weekStartIso: week,
        alarmsCompletedThisWeek: done,
        alarmsAttemptedThisWeek: rang,
      );

  test('a fresh install restores everything from the cloud', () {
    // Exactly the migration case: reinstalled from Play, nothing local yet.
    final local = stats();
    final cloud = stats(streak: 17, last: '2026-08-29', best: 23, xp: 2600, maths: 142);
    final m = StatsCloudSync.merge(local, cloud);
    expect(m.currentStreak, 17);
    expect(m.bestStreak, 23);
    expect(m.totalXp, 2600);
    expect(m.mathSolved, 142);
    expect(m.lastCompletionDateIso, '2026-08-29');
  });

  test('an empty cloud never wipes a local streak', () {
    // The push that happens before migration: local is the truth.
    final local = stats(streak: 9, last: '2026-08-29', best: 9, xp: 900);
    final m = StatsCloudSync.merge(local, stats());
    expect(m.currentStreak, 9);
    expect(m.totalXp, 900);
    expect(m.bestStreak, 9);
  });

  test('counters that only rise take the larger side, whichever way it syncs',
      () {
    final a = stats(xp: 500, best: 12, maths: 40);
    final b = stats(xp: 700, best: 8, maths: 30);
    final m = StatsCloudSync.merge(a, b);
    expect(m.totalXp, 700);
    expect(m.bestStreak, 12);
    expect(m.mathSolved, 40);
    // Merging is symmetric: the order of the two copies cannot matter.
    final n = StatsCloudSync.merge(b, a);
    expect(n.totalXp, m.totalXp);
    expect(n.bestStreak, m.bestStreak);
  });

  test('the streak follows the most recent completion, not the bigger number',
      () {
    // A stale device claiming a longer streak must not overwrite the phone
    // that actually solved today's alarm.
    final stale = stats(streak: 30, last: '2026-08-01');
    final today = stats(streak: 2, last: '2026-08-29');
    expect(StatsCloudSync.merge(stale, today).currentStreak, 2);
    expect(StatsCloudSync.merge(today, stale).currentStreak, 2);
  });

  test('a new week resets the weekly counters instead of inheriting them', () {
    final lastWeek = stats(week: '2026-08-17', done: 6, rang: 7);
    final thisWeek = stats(week: '2026-08-24', done: 1, rang: 1);
    final m = StatsCloudSync.merge(thisWeek, lastWeek);
    expect(m.weekStartIso, '2026-08-24');
    expect(m.alarmsCompletedThisWeek, 1,
        reason: 'last week must not inflate this week');
  });

  test('within one week the weekly counters take the larger side', () {
    final a = stats(week: '2026-08-24', done: 3, rang: 4);
    final b = stats(week: '2026-08-24', done: 5, rang: 5);
    final m = StatsCloudSync.merge(a, b);
    expect(m.alarmsCompletedThisWeek, 5);
    expect(m.alarmsAttemptedThisWeek, 5);
  });
}
