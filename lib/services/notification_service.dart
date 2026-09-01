import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm.dart';
import '../models/routine_block.dart';
import 'focus_dnd_service.dart';
import 'active_user_store.dart';
import 'alarm_repository.dart';

const _pendingRingAlarmKey = 'pendingRingAlarmId';
const _pendingRingBlockKey = 'pendingRingBlockId';
final _vibrationPattern = Int64List.fromList([0, 800, 400, 800, 400, 800]);

/// Runs in the AndroidAlarmManager background isolate when a scheduled
/// alarm fires. This is Dart code we control end-to-end (unlike relying on
/// flutter_local_notifications' native BroadcastReceiver alone), so we can
/// see exactly what happens via debugPrint and post the notification
/// ourselves.
@pragma('vm:entry-point')
void alarmFireCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[WakeForce] alarmFireCallback FIRED id=$id params=$params');

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await plugin.initialize(settings: settings);

  final label = params['label'] as String? ?? 'Wake up!';
  final alarmId = params['alarmId'] as String? ?? '';

  // v3 is deliberately silent. RingForegroundService now owns the alarm tone
  // and starts it the instant the alarm fires, which this callback cannot
  // promise -- it rides a JobService that an OEM freezer defers. Two loud
  // notifications would simply ring over the top of it. This one survives as
  // the full-screen intent and the way back to the mission.
  // (v2 was loud; a channel is immutable once created, so going quiet needs a
  // new id just as going loud did.)
  final androidDetails = AndroidNotificationDetails(
    'alarm_channel_v3',
    'Alarms',
    channelDescription: 'Wake-up alarm notifications',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    playSound: false,
    enableVibration: false,
    ongoing: true,
    autoCancel: false,
  );
  final details = NotificationDetails(android: androidDetails);

  try {
    await plugin.show(
      id: id,
      title: label,
      body: 'Complete your mission to stop the alarm',
      notificationDetails: details,
      payload: alarmId,
    );
    debugPrint('[WakeForce] plugin.show() SUCCEEDED for id=$id');
  } catch (e, st) {
    debugPrint('[WakeForce] plugin.show() FAILED for id=$id: $e\n$st');
  }

  // The notification's full-screen intent may bring the app to the
  // foreground via onNewIntent rather than a fresh cold start, which some
  // OEM Android builds don't reliably route through
  // flutter_local_notifications' tap-detection callback. Persisting the
  // alarm id here lets the main app pick it up on its next resume
  // regardless of how it came back to the foreground.
  //
  // This must be the non-caching SharedPreferencesAsync, not the classic
  // SharedPreferences.getInstance(): the main UI isolate has typically
  // already cached its own in-memory snapshot of prefs by the time this
  // background isolate writes, so it would never see this value otherwise.
  try {
    await SharedPreferencesAsync().setString(_pendingRingAlarmKey, alarmId);
    debugPrint('[WakeForce] pending ring alarm id persisted: $alarmId');
  } catch (e) {
    debugPrint('[WakeForce] failed to persist pending ring alarm id: $e');
  }

  // AndroidAlarmManager.oneShotAt only ever fires once. A repeating alarm
  // (e.g. "weekdays") needs to be explicitly re-armed for its next
  // occurrence here, otherwise it silently stops after the first ring.
  try {
    final uid = await ActiveUserStore.get();
    final alarms = uid == null ? <Alarm>[] : await AlarmRepository(uid).loadAlarms();
    final matches = alarms.where((a) => a.id == alarmId);
    final alarm = matches.isEmpty ? null : matches.first;
    if (alarm != null && alarm.isRepeating && alarm.enabled) {
      final next = alarm.nextOccurrence();
      await AndroidAlarmManager.oneShotAt(
        next,
        id,
        alarmFireCallback,
        alarmClock: true,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: params,
      );
      debugPrint('[WakeForce] re-armed repeating alarm $alarmId for $next');
    }
  } catch (e) {
    debugPrint('[WakeForce] failed to re-arm repeating alarm $alarmId: $e');
  }
}


/// Fires for a routine block's reminder (or its full alarm). Separate from
/// [alarmFireCallback] because a block never opens the mission screen -- it
/// only announces itself and re-arms for its next day.
@pragma('vm:entry-point')
void routineBlockCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await plugin.initialize(settings: settings);

  final title = params['title'] as String? ?? 'Routine block';
  final body = params['body'] as String? ?? '';
  final ringAsAlarm = params['ringAsAlarm'] as bool? ?? false;
  final startsFocus = params['startsFocus'] as bool? ?? false;

  // "Ring as full alarm" borrows the alarm channel so it is loud and
  // full-screen; a plain reminder stays a quiet, dismissible notification.
  final androidDetails = ringAsAlarm
      // Its own channel, not the wake-alarm one: a channel's sound and
      // importance are fixed when it is created, and this one needs the
      // bundled alarm tone at alarm volume rather than whatever the wake
      // channel was first created with.
      // v2 is silent for the same reason as alarm_channel_v3: a block that
      // rings as a full alarm goes through RingForegroundService, which is
      // already playing the tone by the time this runs.
      ? AndroidNotificationDetails(
          'block_alarm_channel_v2',
          'Routine block alarms',
          channelDescription: 'Blocks you asked to ring as a full alarm',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          playSound: false,
          enableVibration: false,
          ongoing: true,
        )
      // v2: the original channel was created silent, and an Android channel
      // is immutable once created -- turning sound on needs a new id or
      // existing installs stay mute.
      // v3 carries its own bundled chime. v2 relied on the phone's default
      // notification sound, which is silent on plenty of handsets -- the
      // student saw the notification appear and heard nothing. A channel's
      // sound is fixed at creation, so changing it needs a new id.
      : AndroidNotificationDetails(
          'routine_channel_v3',
          'Routine reminders',
          channelDescription: 'A short chime when a routine block starts',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('routine_chime'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
        );

  final blockId = params['blockId'] as String? ?? '';

  try {
    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      // Prefixed so the tap handler can tell a block from a wake alarm --
      // they open different screens.
      payload: 'block:$blockId',
    );
  } catch (e) {
    debugPrint('[WakeForce] routine notification failed for id=$id: $e');
  }

  // A block that rings as a full alarm gets a real ringing screen, the same
  // way a wake alarm does. A block that starts a focus session needs the
  // screen too -- that toggle is worthless if nothing ever opens it.
  // Persisted from this background isolate via the non-caching store so the
  // UI isolate actually sees it.
  if ((ringAsAlarm || startsFocus) && blockId.isNotEmpty) {
    try {
      await SharedPreferencesAsync().setString(_pendingRingBlockKey, blockId);
    } catch (e) {
      debugPrint('[WakeForce] failed to persist pending ring block: $e');
    }
  }

  // oneShotAt fires once, so a repeating block has to re-arm itself here or
  // it silently stops after the first day.
  try {
    final startMinute = params['startMinute'] as int? ?? 0;
    final endMinute = params['endMinute'] as int? ?? 0;
    final remind = params['remindBeforeMinutes'] as int? ?? 0;
    final days = (params['days'] as List? ?? const [])
        .map((e) => e as int)
        .toSet();
    final block = RoutineBlock(
      id: params['blockId'] as String? ?? '',
      title: title,
      startMinute: startMinute,
      endMinute: endMinute,
      days: days,
      remindBeforeMinutes: remind,
      ringAsAlarm: ringAsAlarm,
      startsFocus: startsFocus,
    );
    await AndroidAlarmManager.oneShotAt(
      block.nextFireTime(),
      id,
      routineBlockCallback,
      alarmClock: block.opensScreen,
      exact: true,
      // Without this the plugin picks setExact(), which Doze parks until the
      // phone is next used -- so the block went off the moment the app was
      // opened instead of at its own time. See scheduleBlock.
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: params,
    );
  } catch (e) {
    debugPrint('[WakeForce] failed to re-arm routine block $id: $e');
  }
}

/// Schedules alarms via AndroidAlarmManager (which runs [alarmFireCallback]
/// in a background Dart isolate when the alarm fires) and wires up
/// flutter_local_notifications purely for handling notification taps in the
/// main app process.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  void Function(String alarmId)? onAlarmTriggered;

  /// Fired when a routine block that rings as a full alarm is tapped.
  void Function(String blockId)? onBlockTriggered;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    } catch (_) {
      // Fall back to whatever default the timezone package picks; better
      // than crashing alarm scheduling over a timezone lookup failure.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id == null || id.isEmpty) return;
        if (id.startsWith('block:')) {
          onBlockTriggered?.call(id.substring(6));
        } else {
          onAlarmTriggered?.call(id);
        }
      },
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();
    // Android 14+ can silently downgrade fullScreenIntent notifications to a
    // plain tap-to-open banner unless this is explicitly granted, which
    // would otherwise require the user to tap the notification before the
    // ringing screen ever appears.
    await androidImpl?.requestFullScreenIntentPermission();
    // Standard Android API (works the same on every OEM, unlike vendor
    // "autostart" toggles) so the alarm's background isolate isn't frozen
    // or killed by battery optimization before it can fire. Unlike a normal
    // runtime permission, Android doesn't remember a prior dismissal here --
    // calling .request() again always re-shows the system dialog, so without
    // this guard it nags the user on every single app launch. Ask at most
    // once; if they dismissed it, respect that instead of re-prompting.
    try {
      final alreadyGranted =
          await Permission.ignoreBatteryOptimizations.status.isGranted;
      if (!alreadyGranted) {
        final prefs = await SharedPreferences.getInstance();
        const askedKey = 'batteryOptimizationPromptShown';
        if (prefs.getBool(askedKey) != true) {
          await Permission.ignoreBatteryOptimizations.request();
          await prefs.setBool(askedKey, true);
        }
      }
    } catch (_) {
      // Non-fatal -- alarms still fire on most devices without this.
    }

    await AndroidAlarmManager.initialize();

    _initialized = true;
    debugPrint('[WakeForce] NotificationService initialized');
  }

  /// Returns the alarm ID that launched the app from a terminated state by
  /// the user tapping a notification, or null if the app wasn't launched
  /// that way. Must be called after [init].
  Future<String?> getLaunchAlarmId() async {
    if (kIsWeb) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  /// Returns the alarm ID an alarm callback most recently posted a ringing
  /// notification for, without clearing it. See the comment in
  /// [alarmFireCallback] for why this exists alongside [getLaunchAlarmId].
  /// Pair with [clearPendingRingAlarmId] once the caller has actually acted
  /// on it -- callers that can't yet (e.g. alarms still loading) should be
  /// able to see it again on their next check instead of losing it.
  Future<String?> peekPendingRingAlarmId() async {
    if (kIsWeb) return null;
    return SharedPreferencesAsync().getString(_pendingRingAlarmKey);
  }

  /// The block equivalent of [peekPendingRingAlarmId].
  Future<String?> peekPendingRingBlockId() async {
    if (kIsWeb) return null;
    return SharedPreferencesAsync().getString(_pendingRingBlockKey);
  }

  Future<void> clearPendingRingBlockId() async {
    if (kIsWeb) return;
    await SharedPreferencesAsync().remove(_pendingRingBlockKey);
  }

  Future<void> clearPendingRingAlarmId() async {
    if (kIsWeb) return;
    await SharedPreferencesAsync().remove(_pendingRingAlarmKey);
  }

  /// Whether the OS currently allows this app to schedule exact alarms.
  /// Always true on iOS/macOS/web, where this restriction doesn't exist.
  Future<bool> canScheduleExact() async {
    if (kIsWeb) return true;
    await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    return await androidImpl.canScheduleExactNotifications() ?? false;
  }

  /// Opens the OS's exact-alarm permission screen for the user to grant it.
  Future<void> requestExactPermission() async {
    if (kIsWeb) return;
    await init();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestExactAlarmsPermission();
  }

  int _notificationIdFor(String alarmId) => alarmId.hashCode & 0x7fffffff;

  /// Schedules the alarm and returns whether it was scheduled with exact
  /// timing. `false` means it fell back to inexact delivery (still fires,
  /// but the OS may delay it) because the exact alarm permission isn't
  /// granted.
  Future<bool> scheduleAlarm(Alarm alarm) async {
    debugPrint('[WakeForce] scheduleAlarm called for ${alarm.id} enabled=${alarm.enabled}');
    if (kIsWeb) return true;
    await init();
    if (!alarm.enabled) {
      await cancelAlarm(alarm.id);
      return true;
    }

    final next = alarm.nextOccurrence();
    debugPrint('[WakeForce] next occurrence for ${alarm.id}: $next (now: ${DateTime.now()})');

    final id = _notificationIdFor(alarm.id);
    final params = {
      'alarmId': alarm.id,
      'label': alarm.label.isEmpty ? 'Wake up!' : alarm.label,
    };

    // Alongside the notification: this is what actually brings the ringing
    // screen to the front when the OS refuses the full-screen intent.
    await FocusDndService.instance.scheduleNativeRing(
      id: alarm.id,
      kind: 'alarm',
      requestCode: id,
      at: next,
      // null = fires once. A repeating alarm re-arms itself natively for the
      // same reason a block does: nothing in Dart can reach native code from
      // the background isolate that handles the ring.
      repeatDays: alarm.isRepeating ? alarm.repeatDays.toList() : null,
    );

    try {
      final ok = await AndroidAlarmManager.oneShotAt(
        next,
        id,
        alarmFireCallback,
        alarmClock: true,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: params,
      );
      if (!ok) throw StateError('oneShotAt returned false');
      debugPrint('[WakeForce] exact schedule succeeded for ${alarm.id}');
      return true;
    } catch (e) {
      debugPrint('[WakeForce] exact schedule FAILED for ${alarm.id}: $e — falling back to inexact');
      // Most likely the device hasn't granted the exact-alarm permission
      // (Android 12+). Fall back to inexact delivery so the alarm still
      // fires eventually rather than never being scheduled at all.
      await AndroidAlarmManager.oneShotAt(
        next,
        id,
        alarmFireCallback,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: params,
      );
      return false;
    }
  }

  /// Blocks share the alarm id space, so offset them to avoid a routine
  /// block and a wake alarm colliding on the same AlarmManager slot.
  int _blockIdFor(String blockId) => ('block_$blockId').hashCode & 0x7fffffff;

  /// A snooze gets its own slot rather than borrowing the block's. By the
  /// time the student taps snooze the receiver has already armed the block's
  /// next day; reusing that slot would overwrite it with a one-shot and lose
  /// the repeat.
  int _blockSnoozeIdFor(String blockId) =>
      ('block_snooze_$blockId').hashCode & 0x7fffffff;

  /// Schedules (or clears) one block's reminder. A block that neither rings
  /// nor reminds is just a plan on the timeline and schedules nothing.
  Future<void> scheduleBlock(RoutineBlock block) async {
    if (kIsWeb) return;
    await init();
    final id = _blockIdFor(block.id);
    await AndroidAlarmManager.cancel(id);
    if (!block.notifies) return;

    final params = _blockParams(block);

    // Alongside the notification: this is what actually brings the ringing
    // screen to the front when the OS refuses the full-screen intent.
    // Every block, not only the ones that take over the screen. This is the
    // only delivery path that survives an OEM freezing the app process
    // (ColorOS's "Hans" freezer does it ~30s after you leave the app, screen
    // still on): a manifest broadcast wakes a frozen app, the Dart alarm's
    // background isolate does not, so a plain reminder scheduled only through
    // the plugin sat queued until the student happened to open the app.
    //
    // The repeat travels with the alarm and is re-armed natively for the same
    // reason -- by then there is no method channel left to ask.
    await FocusDndService.instance.scheduleNativeRing(
      id: block.id,
      kind: 'block',
      requestCode: id,
      at: block.nextFireTime(),
      repeatDays: block.fireDays.toList(),
      screen: block.opensScreen,
      title: params['title'] as String? ?? block.title,
      body: params['body'] as String? ?? '',
    );

    try {
      await AndroidAlarmManager.oneShotAt(
        block.nextFireTime(),
        id,
        routineBlockCallback,
        alarmClock: block.opensScreen,
        exact: true,
        // exact alone means setExact(), which Doze holds back until the phone
        // is next used. A block has to land at its own time whatever the
        // screen is doing, so it must be allowed while idle.
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: params,
      );
    } catch (e) {
      // Deliberately no inexact retry. Dropping `exact` bought an alarm with a
      // 45-minute delivery window, which is not a schedule the student asked
      // for -- and the native ring above already covers this block whatever
      // happens here.
      debugPrint('[WakeForce] block schedule failed for ${block.id}: $e');
    }
  }

  Map<String, dynamic> _blockParams(RoutineBlock block) => <String, dynamic>{
      'blockId': block.id,
      'title': block.ringAsAlarm ? block.title : '${block.title} coming up',
      'body': block.remindBeforeMinutes > 0
          ? 'Starts at ${RoutineBlock.formatMinute(block.startMinute)} '
              '(in ${block.remindBeforeMinutes}m)'
          : 'Starts now · ${block.timeRangeLabel}',
      'ringAsAlarm': block.ringAsAlarm,
      'startMinute': block.startMinute,
      'endMinute': block.endMinute,
      'remindBeforeMinutes': block.remindBeforeMinutes,
      'days': block.days.toList(),
      'startsFocus': block.startsFocus,
    };

  /// Re-arms a block's alarm a short time from now, leaving its normal
  /// repeat schedule untouched -- snoozing today must not move the block.
  Future<void> snoozeBlock(RoutineBlock block, Duration delay) async {
    if (kIsWeb) return;
    await init();
    await cancelBlockNotification(block.id);
    final id = _blockIdFor(block.id);
    final at = DateTime.now().add(delay);

    // Same as a first ring: the notification's full-screen intent is not
    // enough on its own, so a snoozed block that takes over the screen needs
    // the native ring to bring it back. One-shot -- the block's own repeating
    // ring is untouched in its own slot.
    if (block.opensScreen) {
      await FocusDndService.instance.scheduleNativeRing(
        id: block.id,
        kind: 'block',
        requestCode: _blockSnoozeIdFor(block.id),
        at: at,
      );
    }

    try {
      await AndroidAlarmManager.oneShotAt(
        at,
        id,
        routineBlockCallback,
        alarmClock: block.opensScreen,
        exact: true,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: _blockParams(block),
      );
    } catch (e) {
      debugPrint('[WakeForce] could not snooze block ${block.id}: $e');
    }
  }

  /// Takes down a block's ongoing/insistent alarm notification. Cancelling
  /// the scheduled alarm is a different thing -- see [cancelBlock].
  Future<void> cancelBlockNotification(String blockId) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: _blockIdFor(blockId));
  }

  Future<void> cancelBlock(String blockId) async {
    if (kIsWeb) return;
    await init();
    for (final requestCode in [
      _blockIdFor(blockId),
      // A block deleted while a snooze is pending must not ring anyway.
      _blockSnoozeIdFor(blockId),
    ]) {
      await FocusDndService.instance.cancelNativeRing(
        id: blockId,
        kind: 'block',
        requestCode: requestCode,
      );
    }
    await AndroidAlarmManager.cancel(_blockIdFor(blockId));
  }

  Future<void> cancelAlarm(String alarmId) async {
    if (kIsWeb) return;
    await init();
    await FocusDndService.instance.cancelNativeRing(
      id: alarmId,
      kind: 'alarm',
      requestCode: _notificationIdFor(alarmId),
    );
    await AndroidAlarmManager.cancel(_notificationIdFor(alarmId));
  }

  /// Swaps the loud fallback notification for a silent one once the ringing
  /// screen is actually up.
  ///
  /// The notification is INSISTENT so it keeps ringing when the screen was
  /// never allowed to launch -- but once the screen is in front it would just
  /// be a second alarm playing over the first. It cannot simply be cancelled:
  /// it is also the way back if the student presses Home mid-mission, which
  /// is the only thing stopping them walking away from it.
  Future<void> quieten(String alarmId, String label) async {
    if (kIsWeb) return;
    await init();
    final id = _notificationIdFor(alarmId);
    await _plugin.cancel(id: id);
    await _plugin.show(
      id: id,
      title: label,
      body: 'Complete your mission to stop the alarm',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_silent_channel',
          'Alarm in progress',
          channelDescription: 'Takes you back to a mission you walked away from',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
        ),
      ),
      payload: alarmId,
    );
  }

  /// Dismisses the currently-showing ringing notification for [alarmId].
  /// The notification is posted with `ongoing: true` so the user can't
  /// swipe it away mid-mission; once the mission is actually completed we
  /// have to remove it ourselves.
  Future<void> dismissNotification(String alarmId) async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancel(id: _notificationIdFor(alarmId));
  }
}
