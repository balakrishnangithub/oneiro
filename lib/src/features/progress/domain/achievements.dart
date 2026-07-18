/// One named milestone inside an achievement track.
class Milestone {
  const Milestone(this.threshold, this.name);

  /// Counter value at which this milestone is reached.
  final int threshold;

  /// Original Oneiro milestone name.
  final String name;
}

/// A countable journey (e.g. journal entries) with ascending milestones.
class AchievementTrack {
  const AchievementTrack({
    required this.id,
    required this.title,
    required this.milestones,
  });

  final String id;

  /// Display name of the counter, e.g. `Journal entries`.
  final String title;

  /// Ascending thresholds with their names.
  final List<Milestone> milestones;
}

/// A track plus the dreamer's current counter value.
class AchievementProgress {
  const AchievementProgress(this.track, this.value);

  final AchievementTrack track;
  final int value;

  /// Milestones already reached.
  int get milestonesReached =>
      track.milestones.where((m) => value >= m.threshold).length;

  /// The next milestone to unlock, or null when the track is complete.
  Milestone? get nextMilestone {
    for (final milestone in track.milestones) {
      if (value < milestone.threshold) return milestone;
    }
    return null;
  }

  /// The name of the highest milestone reached so far, if any.
  String? get currentMilestoneName {
    String? name;
    for (final milestone in track.milestones) {
      if (value >= milestone.threshold) {
        name = milestone.name;
      } else {
        break;
      }
    }
    return name;
  }

  bool get isComplete => nextMilestone == null;

  /// Progress towards the next milestone, 0..1 (1 when complete).
  ///
  /// Scaled from the previous threshold, so the bar starts moving with the
  /// very first point after the previous milestone.
  double get progressToNext {
    final next = nextMilestone;
    if (next == null) return 1;
    var previous = 0;
    for (final milestone in track.milestones) {
      if (milestone.threshold == next.threshold) break;
      previous = milestone.threshold;
    }
    if (next.threshold == previous) return 1;
    return ((value - previous) / (next.threshold - previous)).clamp(0.0, 1.0);
  }
}

/// Oneiro's original achievement tracks ("Dreamwalker milestones").
const achievementTracks = <AchievementTrack>[
  AchievementTrack(
    id: 'entries',
    title: 'Journal entries',
    milestones: [
      Milestone(1, 'First Ink'),
      Milestone(10, 'Steady Quill'),
      Milestone(50, 'Night Librarian'),
      Milestone(100, 'Dream Archivist'),
      Milestone(500, 'Eternal Chronicle'),
    ],
  ),
  AchievementTrack(
    id: 'lucid',
    title: 'Lucid dreams',
    milestones: [
      Milestone(1, 'First Awakening'),
      Milestone(5, 'Lucid Spark'),
      Milestone(25, 'Clear Dreamer'),
      Milestone(100, 'Oneironaut'),
    ],
  ),
  AchievementTrack(
    id: 'reality_checks',
    title: 'Reality checks',
    milestones: [
      Milestone(1, 'First Question'),
      Milestone(25, 'Habit Forming'),
      Milestone(100, 'Reality Tester'),
      Milestone(365, 'Daily Questioner'),
      Milestone(1000, 'Wide Awake'),
    ],
  ),
  AchievementTrack(
    id: 'dream_clues',
    title: 'Dream clues heard',
    milestones: [
      Milestone(1, 'First Whisper'),
      Milestone(10, 'Signal Catcher'),
      Milestone(50, 'Night Listener'),
      Milestone(200, 'Totem Tuned'),
    ],
  ),
];

/// Evaluates every track against the dreamer's current counters.
List<AchievementProgress> computeAchievements({
  required int journalEntries,
  required int lucidDreams,
  required int realityChecks,
  required int dreamClues,
}) {
  final values = {
    'entries': journalEntries,
    'lucid': lucidDreams,
    'reality_checks': realityChecks,
    'dream_clues': dreamClues,
  };
  return [
    for (final track in achievementTracks)
      AchievementProgress(track, values[track.id] ?? 0),
  ];
}
