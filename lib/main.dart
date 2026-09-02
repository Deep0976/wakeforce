import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/block_ringing_screen.dart';
import 'screens/ringing_screen.dart';
import 'screens/root_shell.dart';
import 'services/alarm_provider.dart';
import 'services/focus_provider.dart';
import 'services/routine_provider.dart';
import 'services/shield_provider.dart';
import 'services/auth_service.dart';
import 'services/focus_dnd_service.dart';
import 'services/notification_service.dart';
import 'services/settings_provider.dart';
import 'services/stats_provider.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final _lightTheme = buildWakeForceLightTheme();
final _darkTheme = buildWakeForceDarkTheme();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // flutter_local_notifications needs extra JS/service-worker setup to run
  // on the web target; real alarm delivery is mobile-only, so skip it here
  // rather than block startup (the web build is used for UI preview only).
  if (!kIsWeb) {
    await NotificationService.instance.init();
  }
  runApp(const WakeMissionApp());
}

class WakeMissionApp extends StatefulWidget {
  const WakeMissionApp({super.key});

  @override
  State<WakeMissionApp> createState() => _WakeMissionAppState();
}

class _WakeMissionAppState extends State<WakeMissionApp>
    with WidgetsBindingObserver {
  final AlarmProvider _alarmProvider = AlarmProvider();
  final StatsProvider _statsProvider = StatsProvider();
  final SettingsProvider _settingsProvider = SettingsProvider();
  final RoutineProvider _routineProvider = RoutineProvider();
  final FocusProvider _focusProvider = FocusProvider();
  final ShieldProvider _shieldProvider = ShieldProvider();
  String? _activeRingingAlarmId;
  String? _activeRingingBlockId;
  Timer? _pendingAlarmPoll;
  String? _lastUid;
  bool _handledLaunchAlarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.instance.addListener(_onAuthChanged);
    _init();
    // Belt-and-suspenders: a full-screen intent that brings an
    // already-resumed app back to front doesn't always produce a fresh
    // AppLifecycleState.resumed transition (or route through the
    // notification-tap callback) on every OEM build, so the app-state
    // triggers above can miss it entirely. This catches that within a few
    // seconds regardless of how the app came back to the foreground.
    _pendingAlarmPoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        _checkNativePendingRing();
        _checkPendingRingAlarm();
        _checkPendingRingBlock();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.instance.removeListener(_onAuthChanged);
    _pendingAlarmPoll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativePendingRing();
      _checkPendingRingAlarm();
      _checkPendingRingBlock();
    }
  }

  Future<void> _init() async {
    await _settingsProvider.load();
    NotificationService.instance.onAlarmTriggered = _openRingingScreen;
    NotificationService.instance.onBlockTriggered = _openBlockRingingScreen;
  }

  /// Loads (or clears) alarms/stats whenever the signed-in account changes,
  /// so switching Google accounts on this device shows that account's own
  /// data instead of whichever account was last signed in.
  Future<void> _onAuthChanged() async {
    final auth = AuthService.instance;
    if (!auth.loaded) return;
    final uid = auth.currentUser?.uid;
    if (uid == _lastUid) return;
    _lastUid = uid;

    if (uid == null) {
      await _alarmProvider.reset();
      await _statsProvider.reset();
      await _routineProvider.reset();
      await _focusProvider.reset();
      await _shieldProvider.reset();
      return;
    }

    await _alarmProvider.loadForUser(uid);
    await _statsProvider.loadForUser(uid);
    await _routineProvider.loadForUser(uid);
    await _focusProvider.loadForUser(uid);
    await _shieldProvider.loadForUser(uid);

    if (!_handledLaunchAlarm) {
      _handledLaunchAlarm = true;
      final launchAlarmId = await NotificationService.instance.getLaunchAlarmId();
      if (launchAlarmId != null) {
        _openRingingScreen(launchAlarmId);
      } else {
        await _checkPendingRingAlarm();
      }
    }
  }

  /// The ring that launched the app, read off the Intent the native receiver
  /// started us with. This is the path that makes the mission screen appear on
  /// its own; the two below only ever saw a value when the Dart alarm callback
  /// managed to run, which on a phone that freezes the app it often does not.
  Future<void> _checkNativePendingRing() async {
    final pending = await FocusDndService.instance.peekPendingRing();
    if (pending == null) return;
    final isBlock = pending.kind == 'block';
    // Providers may still be loading right after a cold start. Leave it on the
    // Intent so the next poll picks it up rather than dropping the alarm.
    if (isBlock ? !_routineProvider.loaded : !_alarmProvider.loaded) return;
    await FocusDndService.instance.clearPendingRing();
    if (isBlock) {
      _openBlockRingingScreen(pending.id);
    } else {
      _openRingingScreen(pending.id);
    }
  }

  /// Picks up an alarm that fired while this app instance was already
  /// running (e.g. brought forward by a full-screen intent) but whose
  /// notification tap wasn't routed through the plugin's own callback.
  Future<void> _checkPendingRingAlarm() async {
    final pendingId = await NotificationService.instance.peekPendingRingAlarmId();
    if (pendingId == null) return;
    // Alarms may still be loading (e.g. this fires from the very first poll
    // tick right after a cold start); leave the flag in place so the next
    // poll or lifecycle event picks it up instead of silently dropping it.
    if (!_alarmProvider.loaded) return;
    await NotificationService.instance.clearPendingRingAlarmId();
    _openRingingScreen(pendingId);
  }

  /// A routine block that rings as a full alarm opens its own ringing screen,
  /// which is also where "Start Focus" on the block actually takes effect.
  Future<void> _checkPendingRingBlock() async {
    final pendingId =
        await NotificationService.instance.peekPendingRingBlockId();
    if (pendingId == null) return;
    if (!_routineProvider.loaded) return;
    await NotificationService.instance.clearPendingRingBlockId();
    _openBlockRingingScreen(pendingId);
  }

  void _openBlockRingingScreen(String blockId) {
    if (_activeRingingBlockId == blockId) return;
    final matches = _routineProvider.blocks.where((b) => b.id == blockId);
    if (matches.isEmpty) return;
    _activeRingingBlockId = blockId;
    navigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => BlockRingingScreen(block: matches.first),
          ),
        )
        .then((_) => _activeRingingBlockId = null);
  }

  void _openRingingScreen(String alarmId) {
    if (_activeRingingAlarmId == alarmId) return;
    final matches = _alarmProvider.alarms.where((a) => a.id == alarmId);
    if (matches.isEmpty) return;
    _activeRingingAlarmId = alarmId;
    navigatorKey.currentState
        ?.push(
          MaterialPageRoute(builder: (_) => RingingScreen(alarm: matches.first)),
        )
        .then((_) => _activeRingingAlarmId = null);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _alarmProvider),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: _statsProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
        ChangeNotifierProvider.value(value: _routineProvider),
        ChangeNotifierProvider.value(value: _focusProvider),
        ChangeNotifierProvider.value(value: _shieldProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            title: 'WakeForce',
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: settings.themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isSignedIn ? const RootShell() : const LoginScreen();
      },
    );
  }
}
