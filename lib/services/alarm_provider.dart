import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/alarm.dart';
import 'alarm_repository.dart';
import 'notification_service.dart';

class AlarmProvider extends ChangeNotifier {
  AlarmRepository? _repository;
  final _uuid = const Uuid();

  List<Alarm> _alarms = [];
  bool _loaded = false;

  List<Alarm> get alarms => List.unmodifiable(_alarms);
  bool get loaded => _loaded;

  Alarm? get nextAlarm {
    final enabled = _alarms.where((a) => a.enabled).toList();
    if (enabled.isEmpty) return null;
    enabled.sort(
      (a, b) => a.nextOccurrence().compareTo(b.nextOccurrence()),
    );
    return enabled.first;
  }

  /// Loads the signed-in user's alarms and re-registers each enabled one
  /// with the OS alarm scheduler. This must happen on every sign-in: a
  /// reinstall, update, or device reboot clears the OS-level AlarmManager
  /// entries even though the alarm data itself survives in storage, and a
  /// different account signing in on this device must see its own alarms,
  /// not whichever account was last active.
  Future<void> loadForUser(String uid) async {
    _repository = AlarmRepository(uid);
    _loaded = false;
    _alarms = [];
    notifyListeners();
    _alarms = await _repository!.loadAlarms();
    _loaded = true;
    notifyListeners();
    for (final alarm in _alarms.where((a) => a.enabled)) {
      await NotificationService.instance.scheduleAlarm(alarm);
    }
  }

  /// Called on sign-out: clears in-memory alarms and cancels their OS
  /// schedules so a different account signing in on this device doesn't
  /// briefly see (or keep receiving alarms from) the previous account.
  Future<void> reset() async {
    for (final alarm in _alarms) {
      await NotificationService.instance.cancelAlarm(alarm.id);
    }
    _alarms = [];
    _loaded = false;
    _repository = null;
    notifyListeners();
  }

  /// Returns whether the alarm was scheduled with exact timing (false if it
  /// fell back to inexact delivery due to a missing OS permission).
  Future<bool> addAlarm(Alarm alarm) async {
    final newAlarm = alarm.id.isEmpty ? _withNewId(alarm) : alarm;
    _alarms.add(newAlarm);
    await _persist();
    return NotificationService.instance.scheduleAlarm(newAlarm);
  }

  Alarm _withNewId(Alarm alarm) => Alarm(
        id: _uuid.v4(),
        hour: alarm.hour,
        minute: alarm.minute,
        repeatDays: alarm.repeatDays,
        missionType: alarm.missionType,
        difficulty: alarm.difficulty,
        label: alarm.label,
        soundAsset: alarm.soundAsset,
        enabled: alarm.enabled,
        referencePhotoPath: alarm.referencePhotoPath,
      );

  Future<bool> updateAlarm(Alarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index == -1) return true;
    _alarms[index] = alarm;
    await _persist();
    return NotificationService.instance.scheduleAlarm(alarm);
  }

  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
    await _persist();
    await NotificationService.instance.cancelAlarm(id);
  }

  Future<void> toggleAlarm(String id, bool enabled) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index == -1) return;
    _alarms[index] = _alarms[index].copyWith(enabled: enabled);
    await _persist();
    await NotificationService.instance.scheduleAlarm(_alarms[index]);
  }

  String newId() => _uuid.v4();

  Future<void> _persist() async {
    await _repository?.saveAlarms(_alarms);
    notifyListeners();
  }
}
