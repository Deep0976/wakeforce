import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns Do Not Disturb on for the duration of a focus session.
///
/// There is no Flutter plugin for `setInterruptionFilter`, so the toggle
/// reaches native code through a MethodChannel. Every call fails soft: a
/// focus session must never be blocked or crashed by DND being unavailable.
class FocusDndService {
  FocusDndService._();
  static final FocusDndService instance = FocusDndService._();

  static const _channel = MethodChannel('wakeforce/focus');

  /// Whether the OS has granted notification-policy access. This is the
  /// permission; it does not mean DND is currently on.
  Future<bool> isGranted() async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('isDndGranted') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the OS screen where the student grants notification-policy
  /// access. Native rather than permission_handler: this is the screen the
  /// device actually resolves, and the plugin's request was not landing on
  /// it reliably. The caller re-checks on resume -- the student is away in
  /// Settings when this returns, so the answer here means nothing yet.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _voidCall('requestDnd');
    return isGranted();
  }

  /// Whether airplane mode is on right now. The app cannot set it -- no API
  /// has allowed that for years -- so Focus reports the real state instead
  /// of a checkbox that means nothing.
  /// Whether the OS will let a full-screen intent actually take over the
  /// screen. Without it an alarm arrives as a heads-up notification the
  /// student has to tap, which is not what an alarm is supposed to do.
  Future<bool> canFullScreen() => _boolCall('canFullScreen');
  Future<void> requestFullScreen() => _voidCall('requestFullScreen');

  /// Schedules a native alarm that launches the ringing screen directly, so
  /// it does not depend on the notification's full-screen intent.
  /// [repeatDays] are the weekdays (1 = Mon .. 7 = Sun) this ring recurs on,
  /// or null for a one-shot. Native re-arms itself from them, because the
  /// background isolate that runs when the alarm fires has no access to this
  /// channel -- it belongs to the activity's engine, which by then is gone.
  ///
  /// [screen] false means the ring only posts [title]/[body] as a reminder
  /// instead of taking over the screen. It still goes through native code:
  /// a manifest broadcast reaches a frozen app, a background isolate does not.
  Future<bool> scheduleNativeRing({
    required String id,
    required String kind,
    required int requestCode,
    required DateTime at,
    List<int>? repeatDays,
    bool screen = true,
    String title = '',
    String body = '',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('scheduleNativeRing', {
            'id': id,
            'kind': kind,
            'requestCode': requestCode,
            'triggerAtMillis': at.millisecondsSinceEpoch,
            'repeatDays': repeatDays,
            'screen': screen,
            'title': title,
            'body': body,
          }) ??
          false;
    } catch (e) {
      debugPrint('[WakeForce] could not schedule native ring: $e');
      return false;
    }
  }

  Future<void> cancelNativeRing({
    required String id,
    required String kind,
    required int requestCode,
  }) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('cancelNativeRing', {
        'id': id,
        'kind': kind,
        'requestCode': requestCode,
      });
    } catch (_) {}
  }

  Future<bool> isAirplaneOn() => _boolCall('isAirplaneOn');
  Future<void> openAirplaneSettings() => _voidCall('openAirplaneSettings');

  /// Returns whether DND is actually on now -- the caller should trust this
  /// over what the user asked for, so the UI never claims a silence it
  /// didn't get.
  Future<bool> setEnabled(bool on) async {
    if (kIsWeb) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setDnd', {'on': on});
      return (ok ?? false) && on;
    } on PlatformException catch (e) {
      debugPrint('[WakeForce] could not set DND: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> _boolCall(String method) async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _voidCall(String method) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // The OS screen may be unavailable on some builds; the caller re-checks
      // the permission on resume regardless.
    }
  }

  // --- App shield -------------------------------------------------------

  /// Usage access lets the guard see which app is in front; the overlay is
  /// what covers it. Focus still runs without either -- it just falls back to
  /// DND only, and says so rather than claiming a shield it hasn't got.
  Future<bool> hasUsageAccess() => _boolCall('hasUsageAccess');
  Future<bool> hasOverlay() => _boolCall('hasOverlay');
  Future<void> requestUsageAccess() => _voidCall('requestUsageAccess');
  Future<void> requestOverlay() => _voidCall('requestOverlay');

  /// Launchable, non-system apps the student can choose to shield.
  Future<List<InstalledApp>> installedApps() async {
    if (kIsWeb) return const [];
    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
        'installedApps',
      );
      return (raw ?? [])
          .map((m) => InstalledApp(
                packageName: m['package'] as String? ?? '',
                label: m['label'] as String? ?? '',
              ))
          .where((a) => a.packageName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[WakeForce] could not list apps: $e');
      return const [];
    }
  }

  Future<bool> startGuard({
    required List<String> packages,
    required bool block,
  }) async {
    if (kIsWeb || packages.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('startGuard', {
            'packages': packages,
            'block': block,
          }) ??
          false;
    } catch (e) {
      debugPrint('[WakeForce] could not start focus guard: $e');
      return false;
    }
  }

  /// Stops the guard and returns how many times each app was opened, keyed by
  /// the app's display name -- this is the design's "what pulled at you".
  Future<Map<String, int>> stopGuard() async {
    if (kIsWeb) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, int>('stopGuard');
      return raw ?? const {};
    } catch (e) {
      debugPrint('[WakeForce] could not stop focus guard: $e');
      return const {};
    }
  }
}

/// One launchable app the student could choose to shield.
class InstalledApp {
  final String packageName;
  final String label;
  const InstalledApp({required this.packageName, required this.label});
}
