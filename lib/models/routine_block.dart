/// What a block is for. Drives its colour and whether it can start a Focus
/// session -- the design only offers "Start Focus" on study blocks.
enum BlockType { study, breakTime, personal }

extension BlockTypeX on BlockType {
  String get label {
    switch (this) {
      case BlockType.study:
        return 'Study';
      case BlockType.breakTime:
        return 'Break';
      case BlockType.personal:
        return 'Personal';
    }
  }

  bool get canFocus => this == BlockType.study;
}

/// How loudly a block announces itself when it starts.
enum BlockAlert { none, notify, alarm }

/// One entry on the daily routine timeline. Times are minutes-from-midnight
/// so comparisons and sorting stay trivial and there's no date to keep in
/// sync -- a block repeats on weekdays, it isn't tied to one calendar day.
class RoutineBlock {
  final String id;
  final String title;
  final int startMinute;
  final int endMinute;

  /// 1 = Monday ... 7 = Sunday, matching DateTime.weekday and Alarm.repeatDays.
  final Set<int> days;

  final BlockType type;

  /// Minutes of warning before the block starts; 0 means no reminder.
  final int remindBeforeMinutes;

  /// "Ring as full alarm" -- otherwise the reminder is a quiet notification.
  final bool ringAsAlarm;

  /// "Start Focus · study only" -- offers to open a Focus session on start.
  final bool startsFocus;

  const RoutineBlock({
    required this.id,
    required this.title,
    required this.startMinute,
    required this.endMinute,
    required this.days,
    this.type = BlockType.study,
    this.remindBeforeMinutes = 0,
    this.ringAsAlarm = false,
    this.startsFocus = false,
  });

  int get durationMinutes => endMinute - startMinute;

  bool fallsOn(DateTime day) => days.isEmpty || days.contains(day.weekday);

  bool isActiveAt(DateTime now) =>
      fallsOn(now) &&
      _minuteOf(now) >= startMinute &&
      _minuteOf(now) < endMinute;

  /// Minutes left in the block, or 0 once it's over.
  int minutesRemainingAt(DateTime now) {
    final m = _minuteOf(now);
    if (m < startMinute || m >= endMinute) return 0;
    return endMinute - m;
  }

  static int _minuteOf(DateTime d) => d.hour * 60 + d.minute;

  /// Whether this block announces itself at all. A block with no reminder
  /// and no alarm is purely a plan on the timeline -- nothing to schedule.
  /// Every block announces itself. A block you put on the timeline and then
  /// never hear from is the bug students actually reported -- "remind me
  /// before" only moves the alert earlier, it does not switch it on.
  bool get notifies => true;

  /// Every block takes over the screen when it starts, the same way a wake
  /// alarm does. It used to depend on [ringAsAlarm] or [startsFocus], which
  /// meant a plain block only posted a notification and the student had to
  /// tap it to see anything -- a routine you have to go looking for is not a
  /// routine. The two toggles still decide how loud it is, not whether it
  /// appears.
  ///
  /// Also the reason a block is scheduled alarm-grade (setAlarmClock), which
  /// Doze can never hold back -- unlike setExact, which it parks until the
  /// phone is next used.
  bool get opensScreen => true;

  /// The weekdays the alert actually lands on. Not the same as [days] when a
  /// reminder is pushed back over midnight (a 00:10 Tuesday block with 15m of
  /// warning alerts on Monday night). Never empty -- an "every day" block
  /// alerts on all seven, so native code can treat an absent list as
  /// "fires once" without guessing.
  Set<int> get fireDays {
    final offset = startMinute - remindBeforeMinutes < 0 ? -1 : 0;
    final source = days.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : days;
    return source.map((d) => ((d - 1 + offset) % 7 + 7) % 7 + 1).toSet();
  }

  /// When this block should next fire, accounting for the reminder lead-in.
  /// Mirrors Alarm.nextOccurrence so both use the same scheduling shape.
  DateTime nextFireTime({DateTime? from}) {
    final now = from ?? DateTime.now();
    final fireMinute = startMinute - remindBeforeMinutes;

    // A reminder can be pushed before midnight (e.g. 00:10 start, 15m
    // lead-in), so carry the day backwards rather than clamping to 0.
    final dayOffset = fireMinute < 0 ? -1 : 0;
    final minuteInDay = fireMinute < 0 ? fireMinute + 24 * 60 : fireMinute;

    for (var i = 0; i < 8; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final candidate = DateTime(day.year, day.month, day.day)
          .add(Duration(days: dayOffset, minutes: minuteInDay));
      // fallsOn is checked against the block's own day, not the fire day,
      // so a pre-midnight reminder still belongs to the block it precedes.
      if (fallsOn(day) && candidate.isAfter(now)) return candidate;
    }
    return now.add(const Duration(days: 7));
  }

  static String formatMinute(int minute) {
    final h = (minute ~/ 60).toString().padLeft(2, '0');
    final m = (minute % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get timeRangeLabel =>
      '${formatMinute(startMinute)} – ${formatMinute(endMinute)}';

  RoutineBlock copyWith({
    String? title,
    int? startMinute,
    int? endMinute,
    Set<int>? days,
    BlockType? type,
    int? remindBeforeMinutes,
    bool? ringAsAlarm,
    bool? startsFocus,
  }) {
    return RoutineBlock(
      id: id,
      title: title ?? this.title,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      days: days ?? this.days,
      type: type ?? this.type,
      remindBeforeMinutes: remindBeforeMinutes ?? this.remindBeforeMinutes,
      ringAsAlarm: ringAsAlarm ?? this.ringAsAlarm,
      startsFocus: startsFocus ?? this.startsFocus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'days': days.toList(),
        'type': type.name,
        'remindBeforeMinutes': remindBeforeMinutes,
        'ringAsAlarm': ringAsAlarm,
        'startsFocus': startsFocus,
      };

  factory RoutineBlock.fromJson(Map<String, dynamic> json) => RoutineBlock(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        startMinute: json['startMinute'] as int? ?? 0,
        endMinute: json['endMinute'] as int? ?? 0,
        days: (json['days'] as List? ?? const [])
            .map((e) => e as int)
            .toSet(),
        // firstWhere rather than byName so a value written by a future
        // version doesn't crash this one on load.
        type: BlockType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => BlockType.study,
        ),
        remindBeforeMinutes: json['remindBeforeMinutes'] as int? ?? 0,
        ringAsAlarm: json['ringAsAlarm'] as bool? ?? false,
        startsFocus: json['startsFocus'] as bool? ?? false,
      );
}
