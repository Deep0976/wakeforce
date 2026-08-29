class UserStats {
  final int currentStreak;
  final int bestStreak;
  final String? lastCompletionDateIso;
  final int totalXp;
  final int mathSolved;
  final int chemistrySolved;
  final int physicsSolved;
  final int shakeSolved;
  final int photoSolved;
  final String weekStartIso;
  final int alarmsCompletedThisWeek;
  final int alarmsAttemptedThisWeek;

  const UserStats({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletionDateIso,
    this.totalXp = 0,
    this.mathSolved = 0,
    this.chemistrySolved = 0,
    this.physicsSolved = 0,
    this.shakeSolved = 0,
    this.photoSolved = 0,
    required this.weekStartIso,
    this.alarmsCompletedThisWeek = 0,
    this.alarmsAttemptedThisWeek = 0,
  });

  UserStats copyWith({
    int? currentStreak,
    int? bestStreak,
    String? lastCompletionDateIso,
    int? totalXp,
    int? mathSolved,
    int? chemistrySolved,
    int? physicsSolved,
    int? shakeSolved,
    int? photoSolved,
    String? weekStartIso,
    int? alarmsCompletedThisWeek,
    int? alarmsAttemptedThisWeek,
  }) {
    return UserStats(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastCompletionDateIso: lastCompletionDateIso ?? this.lastCompletionDateIso,
      totalXp: totalXp ?? this.totalXp,
      mathSolved: mathSolved ?? this.mathSolved,
      chemistrySolved: chemistrySolved ?? this.chemistrySolved,
      physicsSolved: physicsSolved ?? this.physicsSolved,
      shakeSolved: shakeSolved ?? this.shakeSolved,
      photoSolved: photoSolved ?? this.photoSolved,
      weekStartIso: weekStartIso ?? this.weekStartIso,
      alarmsCompletedThisWeek:
          alarmsCompletedThisWeek ?? this.alarmsCompletedThisWeek,
      alarmsAttemptedThisWeek:
          alarmsAttemptedThisWeek ?? this.alarmsAttemptedThisWeek,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastCompletionDateIso': lastCompletionDateIso,
        'totalXp': totalXp,
        'mathSolved': mathSolved,
        'chemistrySolved': chemistrySolved,
        'physicsSolved': physicsSolved,
        'shakeSolved': shakeSolved,
        'photoSolved': photoSolved,
        'weekStartIso': weekStartIso,
        'alarmsCompletedThisWeek': alarmsCompletedThisWeek,
        'alarmsAttemptedThisWeek': alarmsAttemptedThisWeek,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        lastCompletionDateIso: json['lastCompletionDateIso'] as String?,
        totalXp: json['totalXp'] as int? ?? 0,
        mathSolved: json['mathSolved'] as int? ?? 0,
        chemistrySolved: json['chemistrySolved'] as int? ?? 0,
        physicsSolved: json['physicsSolved'] as int? ?? 0,
        shakeSolved: json['shakeSolved'] as int? ?? 0,
        photoSolved: json['photoSolved'] as int? ?? 0,
        weekStartIso: json['weekStartIso'] as String? ?? '',
        alarmsCompletedThisWeek: json['alarmsCompletedThisWeek'] as int? ?? 0,
        alarmsAttemptedThisWeek: json['alarmsAttemptedThisWeek'] as int? ?? 0,
      );

  /// Keyed by MissionType.name so analytics reports the same strings the
  /// mission_completed event already sends -- note `typing` is the legacy
  /// field name for the Chemistry quiz.
  Map<String, int> get missionCounts => {
        'math': mathSolved,
        'physics': physicsSolved,
        'typing': chemistrySolved,
        'shake': shakeSolved,
        'photo': photoSolved,
      };

  /// The mission this student actually uses most, or 'none' before their
  /// first completion. Ties break in map-literal order (math > typing >
  /// shake > photo) so the reported value doesn't flip between sessions --
  /// with only a few completions per student, ties are common.
  String get preferredMission {
    var best = 'none';
    var bestCount = 0;
    for (final entry in missionCounts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  /// Bucketed because GA4 user properties must be low-cardinality to be
  /// usable as a report segment; a raw streak number would be a distinct
  /// value per student per day.
  String get streakBand {
    if (currentStreak == 0) return '0';
    if (currentStreak <= 2) return '1-2';
    if (currentStreak <= 6) return '3-6';
    if (currentStreak <= 13) return '7-13';
    return '14+';
  }

  /// A streak is only alive if the last completion was today or yesterday.
  /// recordMissionCompleted is otherwise the only place that recomputes it,
  /// so a broken streak kept displaying its stale value for days.
  UserStats withStreakDecay(String todayIso, String yesterdayIso) {
    if (currentStreak == 0) return this;
    if (lastCompletionDateIso == todayIso ||
        lastCompletionDateIso == yesterdayIso) {
      return this;
    }
    return copyWith(currentStreak: 0);
  }
}
