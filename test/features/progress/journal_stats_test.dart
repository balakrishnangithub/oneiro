import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/progress/domain/journal_stats.dart';

EntrySummary entry(
  int year,
  int month,
  int day, {
  bool lucid = false,
  int words = 10,
}) => EntrySummary(
  date: DateTime(year, month, day, 23, 55), // time of day must not matter
  isLucid: lucid,
  wordCount: words,
);

void main() {
  final today = DateTime(2026, 5, 18);

  group('JournalStats.compute', () {
    test('empty journal yields all zeros', () {
      expect(JournalStats.compute(const [], today: today), JournalStats.empty);
    });

    test('single entry today', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 18, lucid: true, words: 42),
      ], today: today);
      expect(stats.totalEntries, 1);
      expect(stats.lucidCount, 1);
      expect(stats.lucidPercent, 100);
      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 1);
      expect(stats.entriesLast7Days, 1);
      expect(stats.entriesLast30Days, 1);
      expect(stats.averageWordsPerEntry, 42);
    });

    test('streak ending yesterday is still alive', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 15),
        entry(2026, 5, 16),
        entry(2026, 5, 17),
      ], today: today);
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
    });

    test('gap today and yesterday breaks the current streak', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 14),
        entry(2026, 5, 15),
      ], today: today);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 2);
    });

    test('a gap day in the middle resets the run', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 16),
        entry(2026, 5, 17),
        entry(2026, 5, 18),
        entry(2026, 5, 10),
        entry(2026, 5, 12), // gap on the 11th
      ], today: today);
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
    });

    test('longest streak can be older than the current streak', () {
      final stats = JournalStats.compute([
        for (var day = 1; day <= 6; day++) entry(2026, 4, day),
        entry(2026, 5, 18),
      ], today: today);
      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 6);
    });

    test('streaks cross month boundaries', () {
      final stats = JournalStats.compute([
        entry(2026, 1, 30),
        entry(2026, 1, 31),
        entry(2026, 2, 1),
        entry(2026, 2, 2),
      ], today: DateTime(2026, 2, 2));
      expect(stats.currentStreak, 4);
      expect(stats.longestStreak, 4);
    });

    test('streaks cross year boundaries', () {
      final stats = JournalStats.compute([
        entry(2025, 12, 31),
        entry(2026, 1, 1),
      ], today: DateTime(2026, 1, 1));
      expect(stats.currentStreak, 2);
    });

    test('two entries on one day count once for streaks', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 17),
        entry(2026, 5, 17),
        entry(2026, 5, 18),
      ], today: today);
      expect(stats.totalEntries, 3);
      expect(stats.currentStreak, 2);
      expect(stats.longestStreak, 2);
    });

    test('last 7 / 30 day windows include today and exclude older', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 18), // today
        entry(2026, 5, 12), // exactly 6 days ago: inside 7-day window
        entry(2026, 5, 11), // 7 days ago: outside 7-day, inside 30-day
        entry(2026, 4, 19), // 29 days ago: inside 30-day window
        entry(2026, 4, 18), // 30 days ago: outside both
      ], today: today);
      expect(stats.entriesLast7Days, 2);
      expect(stats.entriesLast30Days, 4);
    });

    test('future-dated entries are excluded from the windows', () {
      final stats = JournalStats.compute([entry(2026, 5, 20)], today: today);
      expect(stats.entriesLast7Days, 0);
      expect(stats.entriesLast30Days, 0);
      expect(stats.totalEntries, 1);
    });

    test('lucid percent and average words', () {
      final stats = JournalStats.compute([
        entry(2026, 5, 16, lucid: true, words: 30),
        entry(2026, 5, 17, words: 10),
        entry(2026, 5, 18, lucid: true, words: 20),
      ], today: today);
      expect(stats.lucidCount, 2);
      expect(stats.lucidPercent, closeTo(66.67, 0.01));
      expect(stats.averageWordsPerEntry, 20);
    });
  });

  group('weeklyActivity', () {
    // 2026-05-18 is a Monday.
    test('buckets are Monday-anchored, oldest first', () {
      final buckets = weeklyActivity(const [], today: today, weeks: 8);
      expect(buckets, hasLength(8));
      expect(buckets.last.weekStart, DateTime(2026, 5, 18));
      expect(buckets.first.weekStart, DateTime(2026, 3, 30));
      for (final bucket in buckets) {
        expect(bucket.weekStart.weekday, DateTime.monday);
      }
    });

    test('entries land in their week, current week included', () {
      final buckets = weeklyActivity(
        [
          entry(2026, 5, 18), // this Monday
          entry(2026, 5, 17), // Sunday: previous week
          entry(2026, 5, 11), // previous Monday
          entry(2026, 3, 30), // first bucket
          entry(2026, 3, 29), // before the window: dropped
        ],
        today: today,
        weeks: 8,
      );
      expect(buckets.map((b) => b.count).toList(), [1, 0, 0, 0, 0, 0, 2, 1]);
    });
  });
}
