import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/oneiro_database.dart';
import '../../data/providers.dart';
import '../training/training_providers.dart';
import 'domain/achievements.dart';
import 'domain/journal_stats.dart';

/// The calendar day stats are computed against.
///
/// Overridden in tests so streaks and windows are deterministic.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

int _wordCount(String text) =>
    text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;

EntrySummary _summarize(DreamEntry entry) => EntrySummary(
  date: DateTime.fromMillisecondsSinceEpoch(entry.dreamDate),
  isLucid: entry.isLucid,
  wordCount: _wordCount(entry.body),
);

/// Aggregated journal statistics for the progress page.
final journalStatsProvider = StreamProvider<JournalStats>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(dreamRepositoryProvider)
      .watchEntries()
      .map(
        (entries) =>
            JournalStats.compute(entries.map(_summarize), today: today),
      );
});

/// Entries per week for the last 8 weeks (chart data).
final weeklyActivityProvider = StreamProvider<List<WeekBucket>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(dreamRepositoryProvider)
      .watchEntries()
      .map((entries) => weeklyActivity(entries.map(_summarize), today: today));
});

/// Achievement progress over the four counters (entries, lucid dreams,
/// reality checks, dream clues heard).
final achievementsProvider = FutureProvider<List<AchievementProgress>>((
  ref,
) async {
  final dreams = ref.watch(dreamRepositoryProvider);
  final settings = ref.watch(settingsRepositoryProvider);
  final counts = await (
    dreams.countEntries(),
    dreams.countLucid(),
    settings.realityCheckCount(),
    settings.dreamClueCount(),
  ).wait;
  return computeAchievements(
    journalEntries: counts.$1,
    lucidDreams: counts.$2,
    realityChecks: counts.$3,
    dreamClues: counts.$4,
  );
});
