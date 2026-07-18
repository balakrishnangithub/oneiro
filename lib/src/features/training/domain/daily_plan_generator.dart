import 'dart:math';

import 'training_settings.dart';

/// Generates the day's (or night's) pseudo-random reminder times.
///
/// The generator is stateless: callers pass a seeded [Random] per plan, so
/// the same seed + date always produces the same plan. That makes
/// rescheduling idempotent — re-planning after a settings change or reboot
/// yields identical trigger times instead of drifting randomly.
class DailyPlanGenerator {
  const DailyPlanGenerator();

  /// Minimum gap between two trigger times in one plan.
  static const Duration minSpacing = Duration(minutes: 45);

  /// Seed used to build the [Random] for a given calendar date.
  ///
  /// [salt] separates plan kinds that share a date (e.g. day vs. night) so
  /// they don't produce identical sequences.
  static int seedForDate(DateTime date, {int salt = 0}) {
    final dayNumber = date.year * 10000 + date.month * 100 + date.day;
    return dayNumber * 31 + salt;
  }

  /// Salt for daytime reality-check plans.
  static const int daySalt = 1;

  /// Salt for night-time dream-clue plans.
  static const int nightSalt = 2;

  /// Reality-check trigger times for [date], inside the configured day
  /// window, sorted ascending.
  List<DateTime> generateDayPlan(
    TrainingSettings settings,
    DateTime date,
    Random random,
  ) {
    return _generate(
      count: settings.checksPerDay,
      start: _atMinutes(date, settings.dayStartMinutes),
      end: _atMinutes(date, settings.dayEndMinutes),
      random: random,
    );
  }

  /// Dream-clue trigger times for the night that *starts* on [anchorDate].
  ///
  /// When `nightEndMinutes <= nightStartMinutes` the window crosses midnight
  /// and the end falls on the following calendar day.
  List<DateTime> generateNightPlan(
    TrainingSettings settings,
    DateTime anchorDate,
    Random random,
  ) {
    final start = _atMinutes(anchorDate, settings.nightStartMinutes);
    var end = _atMinutes(anchorDate, settings.nightEndMinutes);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return _generate(
      count: settings.cluesPerNight,
      start: start,
      end: end,
      random: random,
    );
  }

  static DateTime _atMinutes(DateTime date, int minutes) {
    final day = DateTime(date.year, date.month, date.day);
    return day.add(Duration(minutes: minutes));
  }

  List<DateTime> _generate({
    required int count,
    required DateTime start,
    required DateTime end,
    required Random random,
  }) {
    if (count <= 0) return const [];
    final windowMinutes = end.difference(start).inMinutes;
    if (windowMinutes <= 0) return const [];

    // Rejection sampling: draw random minutes until the set satisfies the
    // minimum spacing. Bounded attempts keep worst-case windows finite.
    const maxAttempts = 200;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final times = List<DateTime>.generate(
        count,
        (_) => start.add(Duration(minutes: random.nextInt(windowMinutes + 1))),
      )..sort();
      if (_respectsSpacing(times)) return List.unmodifiable(times);
    }

    // Fallback for very tight windows: spread the times evenly (spacing may
    // be tighter than [minSpacing] when the window cannot fit it).
    if (count == 1) {
      return List.unmodifiable([
        start.add(Duration(minutes: windowMinutes ~/ 2)),
      ]);
    }
    final step = windowMinutes / (count - 1);
    return List.unmodifiable(
      List<DateTime>.generate(
        count,
        (i) => start.add(Duration(minutes: (step * i).round())),
      ),
    );
  }

  static bool _respectsSpacing(List<DateTime> sorted) {
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]) < minSpacing) return false;
    }
    return true;
  }
}
