/// Goal mode counts down to a target; open mode counts up until stopped.
enum FocusMode { goal, open }

/// One completed (or abandoned) focus sitting. Persisted so Progress can
/// report focus hours and the completion screen can compare against goal.
class FocusSession {
  final String id;
  final String subject;
  final FocusMode mode;

  /// 0 in open mode -- there is no target to beat.
  final int goalMinutes;

  /// Stored in seconds, not minutes. A 20-second sitting used to truncate to
  /// zero: no XP, nothing in Progress, and a completion screen reading "0m".
  /// Short sessions are exactly the ones a student runs while testing, so
  /// they have to count.
  final int actualSeconds;

  int get actualMinutes => actualSeconds ~/ 60;
  final DateTime startedAt;

  /// False when the student ended early in goal mode.
  final bool reachedGoal;

  /// Whether Do Not Disturb was actually engaged for this sitting.
  final bool wasSilenced;

  /// How many times the student left the app mid-session. This is the
  /// honest version of the design's "what pulled at you": naming the app
  /// they switched to needs usage-access permissions, but counting the
  /// times they walked away needs nothing at all.
  final int interruptions;

  /// How many times each shielded app was opened during the session, keyed by
  /// the app's display name. Empty when the shield wasn't running -- the
  /// completion screen must never invent a breakdown it didn't measure.
  final Map<String, int> appOpens;

  const FocusSession({
    required this.id,
    required this.subject,
    required this.mode,
    required this.goalMinutes,
    required this.actualSeconds,
    required this.startedAt,
    required this.reachedGoal,
    this.wasSilenced = false,
    this.interruptions = 0,
    this.appOpens = const {},
  });

  /// Share of the goal actually sat through, or null when there was no goal.
  ///
  /// An open session used to score a flat 1.0 -- a perfect "100% time on
  /// task" with nothing behind it, which is exactly as misleading as a 100%
  /// success rate over zero alarms. No goal means no score, not a full one.
  double? get timeOnTask {
    if (mode == FocusMode.open || goalMinutes == 0) return null;
    // Seconds, so a sitting shorter than a minute is not scored as zero.
    return (actualSeconds / (goalMinutes * 60)).clamp(0.0, 1.0);
  }

  /// 1 XP a minute, with a bonus for actually finishing what you sat down
  /// for -- mirrors how missions pay more for harder tiers. Any sitting that
  /// actually happened earns at least 1, so a short one is never worth zero.
  int get xpEarned {
    final base = actualSeconds > 0 ? (actualMinutes < 1 ? 1 : actualMinutes) : 0;
    return base + (reachedGoal ? 25 : 0);
  }

  /// "20s", "4m", "1h 05m" -- reads correctly at every scale.
  String get durationLabel {
    if (actualSeconds < 60) return '${actualSeconds}s';
    final h = actualMinutes ~/ 60;
    final m = actualMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'mode': mode.name,
        'goalMinutes': goalMinutes,
        'actualSeconds': actualSeconds,
        'startedAt': startedAt.toIso8601String(),
        'reachedGoal': reachedGoal,
        'wasSilenced': wasSilenced,
        'interruptions': interruptions,
        'appOpens': appOpens,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? '',
        mode: FocusMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => FocusMode.goal,
        ),
        goalMinutes: json['goalMinutes'] as int? ?? 0,
        // Older records stored whole minutes only.
        actualSeconds: json['actualSeconds'] as int? ??
            ((json['actualMinutes'] as int? ?? 0) * 60),
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ??
                DateTime.now(),
        reachedGoal: json['reachedGoal'] as bool? ?? false,
        wasSilenced: json['wasSilenced'] as bool? ?? false,
        interruptions: json['interruptions'] as int? ?? 0,
        appOpens: (json['appOpens'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            const {},
      );
}
