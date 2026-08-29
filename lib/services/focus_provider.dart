import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/focus_session.dart';
import '../models/routine_block.dart';

class FocusRepository {
  final String uid;
  const FocusRepository(this.uid);

  String get _key => 'focusSessions_$uid';

  Future<List<FocusSession>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) => FocusSession.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<FocusSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }
}

class FocusProvider extends ChangeNotifier {
  FocusRepository? _repository;
  final _uuid = const Uuid();

  List<FocusSession> _sessions = [];
  bool _loaded = false;

  bool get loaded => _loaded;
  List<FocusSession> get sessions => List.unmodifiable(_sessions);

  Future<void> loadForUser(String uid) async {
    _repository = FocusRepository(uid);
    _loaded = false;
    _sessions = await _repository!.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> reset() async {
    _sessions = [];
    _loaded = false;
    _repository = null;
    notifyListeners();
  }

  String newId() => _uuid.v4();

  Future<void> record(FocusSession session) async {
    _sessions.add(session);
    await _repository?.save(_sessions);
    notifyListeners();
  }

  // --- Aggregates for the Progress screen -------------------------------

  /// Summed in seconds then converted, so a handful of short sittings adds up
  /// instead of each truncating to zero.
  int get totalFocusMinutes =>
      _sessions.fold(0, (sum, s) => sum + s.actualSeconds) ~/ 60;

  int focusMinutesSince(DateTime from) => _sessions
      .where((s) => s.startedAt.isAfter(from))
      .fold(0, (sum, s) => sum + s.actualSeconds) ~/ 60;

  int get focusMinutesThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return focusMinutesSince(monday);
  }

  int get focusMinutesLastWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final lastMonday = monday.subtract(const Duration(days: 7));
    return _sessions
        .where((s) =>
            s.startedAt.isAfter(lastMonday) && s.startedAt.isBefore(monday))
        .fold(0, (sum, s) => sum + s.actualSeconds) ~/ 60;
  }

  /// Share of the day's study blocks that had a focus session actually
  /// overlapping them. This is what "adherence" means here: not whether the
  /// block existed, but whether the student sat down for it.
  /// Null when the day has no study blocks: there is nothing to adhere to,
  /// which is not the same as having adhered to nothing. Returning 0 showed a
  /// student who had not built a routine yet a failing score for something
  /// they never planned.
  double? adherenceFor(List<RoutineBlock> blocks, DateTime day) {
    final study = blocks.where((b) => b.type.canFocus).toList();
    if (study.isEmpty) return null;

    final midnight = DateTime(day.year, day.month, day.day);
    var honoured = 0;
    for (final b in study) {
      final start = midnight.add(Duration(minutes: b.startMinute));
      final end = midnight.add(Duration(minutes: b.endMinute));
      final sat = _sessions.any((s) {
        final sessionEnd = s.startedAt.add(Duration(seconds: s.actualSeconds));
        // Any overlap counts -- starting late or finishing early is still
        // showing up for the block.
        return s.startedAt.isBefore(end) && sessionEnd.isAfter(start);
      });
      if (sat) honoured++;
    }
    return honoured / study.length;
  }

  /// Share of goal-mode sittings that actually reached their goal, or null
  /// when none have been sat. Open sessions are excluded -- they have nothing
  /// to be on task against.
  double? get timeOnTask {
    final graded = _sessions
        .where((s) => s.mode == FocusMode.goal && s.timeOnTask != null)
        .toList();
    if (graded.isEmpty) return null;
    final total = graded.fold<double>(0, (sum, s) => sum + s.timeOnTask!);
    return (total / graded.length).clamp(0.0, 1.0);
  }
}
