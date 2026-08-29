import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_mission_app/models/alarm.dart';
import 'package:wake_mission_app/models/mission_type.dart';
import 'package:wake_mission_app/services/stats_provider.dart';

/// "0 alarms solved, 0 alarms rang, but 100% success rate."
///
/// A rate over zero attempts is undefined, not perfect. Reporting 1.0 gave a
/// student who had never been woken a flattering number with nothing behind
/// it -- and made the whole card untrustworthy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<StatsProvider> loaded() async {
    final s = StatsProvider();
    await s.loadForUser('u1');
    return s;
  }

  test('no alarms rung means no rate at all, not 100%', () async {
    final stats = await loaded();
    expect(stats.stats.alarmsAttemptedThisWeek, 0);
    expect(stats.successRateThisWeek, isNull,
        reason: 'undefined must not be dressed up as perfect');
  });

  test('an alarm that rang and was solved is 100%', () async {
    final stats = await loaded();
    await stats.recordMissionAttempted();
    await stats.recordMissionCompleted(
      MissionType.math,
      MissionDifficulty.easy,
    );
    expect(stats.successRateThisWeek, 1.0);
  });

  test('an alarm that rang and was not solved is 0%, not undefined', () async {
    final stats = await loaded();
    await stats.recordMissionAttempted();
    expect(stats.successRateThisWeek, 0.0,
        reason: 'a missed alarm is a real zero and must be shown as one');
  });
}
