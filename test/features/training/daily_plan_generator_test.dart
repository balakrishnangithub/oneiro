import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/training/domain/daily_plan_generator.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';

void main() {
  const generator = DailyPlanGenerator();
  final date = DateTime(2026, 5, 18);

  DateTime atMinutes(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

  group('day plan', () {
    test('returns the requested number of checks, sorted', () {
      const settings = TrainingSettings(checksPerDay: 5);
      final times = generator.generateDayPlan(settings, date, Random(42));

      expect(times, hasLength(5));
      final sorted = List<DateTime>.of(times)..sort();
      expect(times, sorted);
    });

    test('all triggers fall inside the day window', () {
      const settings = TrainingSettings(
        checksPerDay: 8,
        dayStartMinutes: 9 * 60,
        dayEndMinutes: 21 * 60,
      );
      final times = generator.generateDayPlan(settings, date, Random(7));
      final start = atMinutes(date, 9 * 60);
      final end = atMinutes(date, 21 * 60);

      for (final t in times) {
        expect(t.isBefore(start), isFalse, reason: '$t before window');
        expect(t.isAfter(end), isFalse, reason: '$t after window');
      }
    });

    test('respects the 45-minute minimum spacing', () {
      const settings = TrainingSettings(checksPerDay: 10);
      final times = generator.generateDayPlan(settings, date, Random(99));

      for (var i = 1; i < times.length; i++) {
        expect(
          times[i].difference(times[i - 1]),
          greaterThanOrEqualTo(DailyPlanGenerator.minSpacing),
          reason: '${times[i - 1]} and ${times[i]} too close',
        );
      }
    });

    test('same seed and date produce the identical plan', () {
      const settings = TrainingSettings(checksPerDay: 4);
      final first = generator.generateDayPlan(settings, date, Random(123));
      final second = generator.generateDayPlan(settings, date, Random(123));

      expect(first, second);
    });

    test('zero checks produces an empty plan', () {
      const settings = TrainingSettings(checksPerDay: 0);
      expect(generator.generateDayPlan(settings, date, Random(1)), isEmpty);
    });

    test('degenerate window produces an empty plan', () {
      const settings = TrainingSettings(
        checksPerDay: 3,
        dayStartMinutes: 22 * 60,
        dayEndMinutes: 8 * 60,
      );
      expect(generator.generateDayPlan(settings, date, Random(1)), isEmpty);
    });
  });

  group('night plan', () {
    test('same-day window stays on the anchor date', () {
      const settings = TrainingSettings(
        cluesPerNight: 6,
        nightStartMinutes: 2 * 60 + 30,
        nightEndMinutes: 7 * 60 + 30,
      );
      final times = generator.generateNightPlan(settings, date, Random(5));

      expect(times, hasLength(6));
      for (final t in times) {
        expect(t.isBefore(atMinutes(date, 150)), isFalse);
        expect(t.isAfter(atMinutes(date, 450)), isFalse);
      }
    });

    test('window crossing midnight rolls into the next day', () {
      const settings = TrainingSettings(
        cluesPerNight: 10,
        nightStartMinutes: 23 * 60,
        nightEndMinutes: 6 * 60,
      );
      final times = generator.generateNightPlan(settings, date, Random(5));
      final start = atMinutes(date, 23 * 60);
      final end = atMinutes(date.add(const Duration(days: 1)), 6 * 60);

      expect(times, hasLength(10));
      for (final t in times) {
        expect(t.isBefore(start), isFalse, reason: '$t before window');
        expect(t.isAfter(end), isFalse, reason: '$t after window');
      }
      // With ten samples over a seven-hour window, some land after midnight.
      expect(times.any((t) => t.isAfter(atMinutes(date, 24 * 60))), isTrue);
      expect(times.any((t) => t.isBefore(atMinutes(date, 24 * 60))), isTrue);
    });

    test('same seed and anchor produce the identical plan', () {
      const settings = TrainingSettings(cluesPerNight: 10);
      final first = generator.generateNightPlan(settings, date, Random(77));
      final second = generator.generateNightPlan(settings, date, Random(77));

      expect(first, second);
    });

    test('seedForDate is stable per date and salt', () {
      expect(
        DailyPlanGenerator.seedForDate(date, salt: DailyPlanGenerator.daySalt),
        DailyPlanGenerator.seedForDate(
          DateTime(2026, 5, 18),
          salt: DailyPlanGenerator.daySalt,
        ),
      );
      expect(
        DailyPlanGenerator.seedForDate(date, salt: DailyPlanGenerator.daySalt),
        isNot(
          DailyPlanGenerator.seedForDate(
            date,
            salt: DailyPlanGenerator.nightSalt,
          ),
        ),
      );
    });
  });
}
