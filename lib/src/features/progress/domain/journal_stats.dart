import '../../../core/utils/date_x.dart';

/// The minimum a stat computation needs to know about one journal entry.
class EntrySummary {
  const EntrySummary({
    required this.date,
    required this.isLucid,
    required this.wordCount,
  });

  /// Dream day (any time of day is fine; it is normalized internally).
  final DateTime date;
  final bool isLucid;

  /// Number of words in the entry body.
  final int wordCount;
}

/// Aggregated journal statistics, computed from entry summaries.
///
/// Pure Dart: pass [today] explicitly so tests are deterministic.
class JournalStats {
  const JournalStats({
    required this.totalEntries,
    required this.lucidCount,
    required this.lucidPercent,
    required this.currentStreak,
    required this.longestStreak,
    required this.entriesLast7Days,
    required this.entriesLast30Days,
    required this.averageWordsPerEntry,
  });

  final int totalEntries;
  final int lucidCount;

  /// Lucid entries as a percentage of all entries, 0–100 (0 when empty).
  final double lucidPercent;

  /// Consecutive days with ≥1 entry ending today (or yesterday, if today
  /// has no entry yet — the streak is still alive).
  final int currentStreak;

  /// Longest run of consecutive days with ≥1 entry, ever.
  final int longestStreak;

  /// Entries dated within the last 7 calendar days, including today.
  final int entriesLast7Days;

  /// Entries dated within the last 30 calendar days, including today.
  final int entriesLast30Days;

  /// Mean words per entry (0 when the journal is empty).
  final double averageWordsPerEntry;

  static const empty = JournalStats(
    totalEntries: 0,
    lucidCount: 0,
    lucidPercent: 0,
    currentStreak: 0,
    longestStreak: 0,
    entriesLast7Days: 0,
    entriesLast30Days: 0,
    averageWordsPerEntry: 0,
  );

  /// Computes all stats for [entries] as of calendar day [today].
  factory JournalStats.compute(
    Iterable<EntrySummary> entries, {
    required DateTime today,
  }) {
    final list = entries.toList();
    if (list.isEmpty) return empty;

    final todayStart = today.startOfDay;
    final days = <DateTime>{};
    var lucid = 0;
    var words = 0;
    var last7 = 0;
    var last30 = 0;
    final cutoff7 = todayStart.subtract(const Duration(days: 6));
    final cutoff30 = todayStart.subtract(const Duration(days: 29));

    for (final entry in list) {
      final day = entry.date.startOfDay;
      days.add(day);
      if (entry.isLucid) lucid++;
      words += entry.wordCount;
      if (!day.isBefore(cutoff7) && !day.isAfter(todayStart)) last7++;
      if (!day.isBefore(cutoff30) && !day.isAfter(todayStart)) last30++;
    }

    return JournalStats(
      totalEntries: list.length,
      lucidCount: lucid,
      lucidPercent: lucid * 100 / list.length,
      currentStreak: _currentStreak(days, todayStart),
      longestStreak: _longestStreak(days),
      entriesLast7Days: last7,
      entriesLast30Days: last30,
      averageWordsPerEntry: words / list.length,
    );
  }

  static int _currentStreak(Set<DateTime> days, DateTime todayStart) {
    // The streak is alive if an entry exists today or yesterday.
    var cursor = days.contains(todayStart)
        ? todayStart
        : todayStart.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int _longestStreak(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      run = previous != null && day.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > longest) longest = run;
      previous = day;
    }
    return longest;
  }
}

/// Entry count for one calendar week (Monday-anchored).
class WeekBucket {
  const WeekBucket({required this.weekStart, required this.count});

  /// Local midnight of the Monday starting this week.
  final DateTime weekStart;
  final int count;
}

/// Entries per week for the last [weeks] weeks, oldest first, including the
/// current (possibly partial) week. Weeks are Monday-anchored.
List<WeekBucket> weeklyActivity(
  Iterable<EntrySummary> entries, {
  required DateTime today,
  int weeks = 8,
}) {
  final todayStart = today.startOfDay;
  // DateTime.weekday: Monday = 1 ... Sunday = 7.
  final thisMonday = todayStart.subtract(
    Duration(days: todayStart.weekday - 1),
  );
  final firstMonday = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));

  final counts = List<int>.filled(weeks, 0);
  for (final entry in entries) {
    // `~/` truncates towards zero, so guard the day offset before dividing.
    final dayOffset = entry.date.startOfDay.difference(firstMonday).inDays;
    if (dayOffset < 0) continue;
    final offset = dayOffset ~/ 7;
    if (offset < weeks) counts[offset]++;
  }
  return [
    for (var i = 0; i < weeks; i++)
      WeekBucket(
        weekStart: firstMonday.add(Duration(days: 7 * i)),
        count: counts[i],
      ),
  ];
}
