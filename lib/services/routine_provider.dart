import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/routine_block.dart';
import 'notification_service.dart';

/// Per-account, matching AlarmRepository/StatsRepository -- a second Google
/// account on the same device must not inherit the first student's routine.
class RoutineRepository {
  final String uid;
  const RoutineRepository(this.uid);

  String get _key => 'routineBlocks_$uid';

  Future<List<RoutineBlock>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => RoutineBlock.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<RoutineBlock> blocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      blocks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }
}

/// Injected so tests can run the provider without a device: the real
/// implementation reaches AndroidAlarmManager, which never completes its
/// initialize() call off-platform and would hang the suite.
typedef BlockScheduler = Future<void> Function(RoutineBlock block);
typedef BlockCanceller = Future<void> Function(String blockId);

class RoutineProvider extends ChangeNotifier {
  RoutineRepository? _repository;
  final _uuid = const Uuid();

  final BlockScheduler _scheduler;
  final BlockCanceller _canceller;

  RoutineProvider({
    BlockScheduler? scheduler,
    BlockCanceller? canceller,
  })  : _scheduler =
            scheduler ?? NotificationService.instance.scheduleBlock,
        _canceller = canceller ?? NotificationService.instance.cancelBlock;

  List<RoutineBlock> _blocks = [];
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Always sorted by start time: the timeline reads top-to-bottom by clock.
  List<RoutineBlock> get blocks => List.unmodifiable(_blocks);

  List<RoutineBlock> blocksFor(DateTime day) {
    final list = _blocks.where((b) => b.fallsOn(day)).toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  /// The block covering [now], if any -- drives the "NOW · 42M LEFT" state.
  RoutineBlock? activeBlockAt(DateTime now) {
    for (final b in blocksFor(now)) {
      if (b.isActiveAt(now)) return b;
    }
    return null;
  }

  /// The next block that hasn't started yet today.
  RoutineBlock? nextBlockAfter(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    for (final b in blocksFor(now)) {
      if (b.startMinute > minute) return b;
    }
    return null;
  }

  int plannedMinutesFor(DateTime day) =>
      blocksFor(day).fold(0, (sum, b) => sum + b.durationMinutes);

  Future<void> loadForUser(String uid) async {
    _repository = RoutineRepository(uid);
    _loaded = false;
    _blocks = await _repository!.load();
    _loaded = true;
    notifyListeners();
    // A reinstall, update or reboot clears AlarmManager's entries even
    // though the blocks themselves survive, so re-arm every one on load --
    // same reason AlarmProvider.loadForUser reschedules its alarms.
    for (final block in _blocks) {
      await _schedule(block);
    }
  }

  Future<void> reset() async {
    for (final block in _blocks) {
      await _cancel(block.id);
    }
    _blocks = [];
    _loaded = false;
    _repository = null;
    notifyListeners();
  }

  Future<void> upsert(RoutineBlock block) async {
    final index = _blocks.indexWhere((b) => b.id == block.id);
    if (index == -1) {
      _blocks.add(block);
    } else {
      _blocks[index] = block;
    }
    await _persist();
    await _schedule(block);
  }

  Future<void> delete(String id) async {
    _blocks.removeWhere((b) => b.id == id);
    await _persist();
    await _cancel(id);
  }

  /// Scheduling is best-effort and deliberately swallowed: the OS alarm
  /// scheduler can refuse (missing exact-alarm permission, no platform
  /// channel in tests), and a block the student typed in must still save
  /// and appear on the timeline regardless.
  Future<void> _schedule(RoutineBlock block) async {
    try {
      await _scheduler(block);
    } catch (e) {
      debugPrint('[WakeForce] could not schedule block ${block.id}: $e');
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await _canceller(id);
    } catch (e) {
      debugPrint('[WakeForce] could not cancel block $id: $e');
    }
  }

  String newId() => _uuid.v4();

  Future<void> _persist() async {
    await _repository?.save(_blocks);
    notifyListeners();
  }
}
