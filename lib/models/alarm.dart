import 'mission_type.dart';

enum MissionDifficulty { easy, medium, hard, advanced }

class Alarm {
  final String id;
  final int hour;
  final int minute;
  final Set<int> repeatDays; // 1 = Monday ... 7 = Sunday (DateTime weekday)
  final MissionType missionType;
  final MissionDifficulty difficulty;
  final String label;
  final String soundAsset;
  final bool enabled;
  /// Reference photo of the student's notes/textbook, captured at alarm
  /// setup time. Only used by [MissionType.photo]; the wake-time photo must
  /// visually match this one (see PhotoSimilarity) before the alarm stops.
  final String? referencePhotoPath;

  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.repeatDays,
    required this.missionType,
    this.difficulty = MissionDifficulty.easy,
    this.label = '',
    this.soundAsset = 'alarm_default',
    this.enabled = true,
    this.referencePhotoPath,
  });

  Alarm copyWith({
    int? hour,
    int? minute,
    Set<int>? repeatDays,
    MissionType? missionType,
    MissionDifficulty? difficulty,
    String? label,
    String? soundAsset,
    bool? enabled,
    String? referencePhotoPath,
  }) {
    return Alarm(
      id: id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      missionType: missionType ?? this.missionType,
      difficulty: difficulty ?? this.difficulty,
      label: label ?? this.label,
      soundAsset: soundAsset ?? this.soundAsset,
      enabled: enabled ?? this.enabled,
      referencePhotoPath: referencePhotoPath ?? this.referencePhotoPath,
    );
  }

  String get timeLabel {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get isRepeating => repeatDays.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'repeatDays': repeatDays.toList(),
        'missionType': missionType.name,
        'difficulty': difficulty.name,
        'label': label,
        'soundAsset': soundAsset,
        'enabled': enabled,
        'referencePhotoPath': referencePhotoPath,
      };

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'] as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        repeatDays: (json['repeatDays'] as List).map((e) => e as int).toSet(),
        missionType: MissionType.values.byName(json['missionType'] as String),
        difficulty: MissionDifficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => MissionDifficulty.easy,
        ),
        label: json['label'] as String? ?? '',
        soundAsset: json['soundAsset'] as String? ?? 'alarm_default',
        enabled: json['enabled'] as bool? ?? true,
        referencePhotoPath: json['referencePhotoPath'] as String?,
      );

  /// Computes the next DateTime this alarm should fire, relative to [from].
  DateTime nextOccurrence({DateTime? from}) {
    final now = from ?? DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);

    if (!isRepeating) {
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    for (var i = 0; i < 8; i++) {
      final day = candidate.add(Duration(days: i));
      final fireTime = DateTime(day.year, day.month, day.day, hour, minute);
      if (repeatDays.contains(fireTime.weekday) && fireTime.isAfter(now)) {
        return fireTime;
      }
    }
    return candidate.add(const Duration(days: 7));
  }
}
