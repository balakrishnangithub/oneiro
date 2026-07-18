import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/training/data/notification_scheduler.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';

import '../../support/fake_training_services.dart';

void main() {
  final now = DateTime(2026, 5, 18, 12, 0); // a Monday at noon
  late FakeNotificationGateway gateway;

  NotificationScheduler makeScheduler() =>
      NotificationScheduler(gateway: gateway, clock: () => now);

  List<ScheduledNotification> oneShots(String payload) =>
      gateway.scheduled.where((n) => !n.daily && n.payload == payload).toList();

  setUp(() => gateway = FakeNotificationGateway());

  test('replan initializes, cancels, then reschedules', () async {
    await makeScheduler().replan(const TrainingSettings());

    expect(gateway.initialized, isTrue);
    expect(gateway.cancelCount, 1);
  });

  test(
    'schedules reality checks for today and tomorrow in the future',
    () async {
      await makeScheduler().replan(const TrainingSettings());

      final checks = oneShots(TrainingPayloads.realityCheck);
      final tomorrow = DateTime(2026, 5, 19);
      final tomorrowChecks = checks
          .where(
            (n) =>
                n.at!.year == tomorrow.year &&
                n.at!.month == tomorrow.month &&
                n.at!.day == tomorrow.day,
          )
          .toList();

      // All three of tomorrow's checks are scheduled; today's past ones are
      // dropped.
      expect(tomorrowChecks, hasLength(3));
      for (final n in checks) {
        expect(n.at!.isAfter(now), isTrue, reason: '${n.at} not in the future');
        expect(n.at!.hour, greaterThanOrEqualTo(8));
        expect(n.at!.hour, lessThan(22));
        expect(n.playSound, isTrue);
      }
    },
  );

  test('re-planning is idempotent: same settings yield the same ids', () async {
    const settings = TrainingSettings(dreamCluesEnabled: true);
    final scheduler = makeScheduler();

    await scheduler.replan(settings);
    final firstIds = gateway.scheduled.map((n) => n.id).toSet();

    await scheduler.replan(settings);
    final secondIds = gateway.scheduled.map((n) => n.id).toSet();

    expect(secondIds, firstIds);
    expect(gateway.cancelCount, 2);
  });

  test('notification ids are deterministic and kind-distinct', () {
    final at = DateTime(2026, 5, 18, 14, 30);
    expect(
      NotificationScheduler.idFor(TrainingNotificationKind.realityCheck, at),
      NotificationScheduler.idFor(TrainingNotificationKind.realityCheck, at),
    );
    expect(
      NotificationScheduler.idFor(TrainingNotificationKind.realityCheck, at),
      isNot(
        NotificationScheduler.idFor(TrainingNotificationKind.dreamClue, at),
      ),
    );
  });

  test('a pause suppresses training but not the morning reminder', () async {
    final settings = TrainingSettings(
      dreamCluesEnabled: true,
      pausedUntil: now.add(const Duration(days: 2)),
    );
    await makeScheduler().replan(settings);

    expect(oneShots(TrainingPayloads.realityCheck), isEmpty);
    expect(oneShots(TrainingPayloads.dreamClue), isEmpty);
    final morning = gateway.scheduled.where((n) => n.daily);
    expect(morning, hasLength(1));
    expect(morning.single.minutesOfDay, 5 * 60);
  });

  test('expired pause schedules training normally', () async {
    final settings = TrainingSettings(
      pausedUntil: now.subtract(const Duration(days: 1)),
    );
    await makeScheduler().replan(settings);

    expect(oneShots(TrainingPayloads.realityCheck), isNotEmpty);
  });

  test('dream clues land in tonight\'s window, silent', () async {
    const settings = TrainingSettings(
      dreamCluesEnabled: true,
      cluesPerNight: 5,
      nightStartMinutes: 2 * 60 + 30,
      nightEndMinutes: 7 * 60 + 30,
    );
    await makeScheduler().replan(settings);

    final clues = oneShots(TrainingPayloads.dreamClue);
    expect(clues, hasLength(5));
    final windowStart = DateTime(2026, 5, 19, 2, 30);
    final windowEnd = DateTime(2026, 5, 19, 7, 30);
    for (final n in clues) {
      expect(n.at!.isBefore(windowStart), isFalse, reason: '${n.at} early');
      expect(n.at!.isAfter(windowEnd), isFalse, reason: '${n.at} late');
      expect(n.playSound, isFalse);
    }
  });

  test(
    'night window crossing midnight schedules across the boundary',
    () async {
      const settings = TrainingSettings(
        dreamCluesEnabled: true,
        cluesPerNight: 4,
        nightStartMinutes: 23 * 60,
        nightEndMinutes: 6 * 60,
      );
      await makeScheduler().replan(settings);

      final clues = oneShots(TrainingPayloads.dreamClue);
      // Tonight (18th 23:00 → 19th 06:00) plus tomorrow night (19th 23:00 →
      // 20th 06:00); yesterday's anchored window is entirely in the past.
      expect(clues, hasLength(8));
      for (final n in clues) {
        expect(n.at!.isAfter(now), isTrue);
        final inTonight =
            !n.at!.isBefore(DateTime(2026, 5, 18, 23)) &&
            !n.at!.isAfter(DateTime(2026, 5, 19, 6));
        final inTomorrowNight =
            !n.at!.isBefore(DateTime(2026, 5, 19, 23)) &&
            !n.at!.isAfter(DateTime(2026, 5, 20, 6));
        expect(inTonight || inTomorrowNight, isTrue, reason: '${n.at} outside');
      }
    },
  );

  test('morning reminder can be turned off', () async {
    const settings = TrainingSettings(morningReminderEnabled: false);
    await makeScheduler().replan(settings);

    expect(gateway.scheduled.where((n) => n.daily), isEmpty);
  });

  test('reality checks can be turned off', () async {
    const settings = TrainingSettings(realityChecksEnabled: false);
    await makeScheduler().replan(settings);

    expect(oneShots(TrainingPayloads.realityCheck), isEmpty);
  });
}
