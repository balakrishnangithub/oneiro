import 'dart:math';

import '../domain/daily_plan_generator.dart';
import '../domain/pause_service.dart';
import '../domain/training_settings.dart';
import 'notification_gateway.dart';

/// The three kinds of training notifications.
enum TrainingNotificationKind { realityCheck, morningReminder, dreamClue }

/// Payload prefixes routed when a notification is tapped.
abstract final class TrainingPayloads {
  static const realityCheck = 'oneiro://reality-check';
  static const dreamClue = 'oneiro://dream-clue';
  static const morningReminder = 'oneiro://morning-reminder';
}

/// Turns [TrainingSettings] into concrete scheduled notifications.
///
/// Pure planning logic: it computes trigger times with [DailyPlanGenerator]
/// and delegates all OS interaction to the injected [NotificationGateway],
/// so the whole class is unit-testable with a fake gateway.
class NotificationScheduler {
  NotificationScheduler({
    required NotificationGateway gateway,
    DailyPlanGenerator planGenerator = const DailyPlanGenerator(),
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _planGenerator = planGenerator,
       _clock = clock ?? DateTime.now;

  final NotificationGateway _gateway;
  final DailyPlanGenerator _planGenerator;
  final DateTime Function() _clock;

  /// Fixed id for the repeating morning reminder (one per app, always
  /// replaced on re-plan).
  static const int morningReminderId = 900001;

  /// Deterministic notification id for one-shot triggers.
  ///
  /// Derived from the trigger instant so re-planning produces the same ids
  /// (and `zonedSchedule` would overwrite rather than duplicate even without
  /// the preceding `cancelAll`). Fits comfortably in a 32-bit int.
  static int idFor(TrainingNotificationKind kind, DateTime at) =>
      (at.millisecondsSinceEpoch ~/ 60000 % 100000) * 10 + kind.index;

  /// Cancels everything and rebuilds the schedule from [settings]:
  ///
  /// - reality checks for today and tomorrow (times in the past skipped),
  /// - tonight's dream clues (the night window may cross midnight),
  /// - the daily morning journal reminder.
  ///
  /// A training pause suppresses reality checks and dream clues, but never
  /// the morning reminder.
  Future<void> replan(TrainingSettings settings) async {
    await _gateway.initialize();
    await _gateway.cancelAll();

    final now = _clock();
    final paused = PauseService.isPaused(settings, now);

    if (!paused && settings.realityChecksEnabled) {
      await _planRealityChecks(settings, now);
    }
    if (!paused && settings.dreamCluesEnabled) {
      await _planDreamClues(settings, now);
    }
    if (settings.morningReminderEnabled) {
      await _gateway.scheduleDaily(
        id: morningReminderId,
        minutesOfDay: settings.morningMinutes,
        title: 'Good morning, dreamer',
        body: 'Dreams fade fast — jot down whatever you remember.',
        payload: TrainingPayloads.morningReminder,
      );
    }
  }

  Future<void> _planRealityChecks(TrainingSettings settings, DateTime now) {
    final planned = <Future<void>>[];
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final date = now.add(Duration(days: dayOffset));
      final random = Random(
        DailyPlanGenerator.seedForDate(date, salt: DailyPlanGenerator.daySalt),
      );
      for (final at in _planGenerator.generateDayPlan(
        settings,
        date,
        random,
      )) {
        if (!at.isAfter(now)) continue;
        planned.add(
          _gateway.scheduleOnce(
            id: idFor(TrainingNotificationKind.realityCheck, at),
            at: at,
            title: 'Reality check',
            body: 'Pause and ask yourself: am I dreaming right now?',
            payload: TrainingPayloads.realityCheck,
            playSound: settings.dayAlertSound,
          ),
        );
      }
    }
    return Future.wait(planned);
  }

  Future<void> _planDreamClues(TrainingSettings settings, DateTime now) {
    final planned = <Future<void>>[];
    // Anchor the night window to yesterday, today and tomorrow so that
    // "tonight" is covered whether the window crosses midnight or not.
    for (var dayOffset = -1; dayOffset <= 1; dayOffset++) {
      final anchor = now.add(Duration(days: dayOffset));
      final random = Random(
        DailyPlanGenerator.seedForDate(
          anchor,
          salt: DailyPlanGenerator.nightSalt,
        ),
      );
      for (final at in _planGenerator.generateNightPlan(
        settings,
        anchor,
        random,
      )) {
        if (!at.isAfter(now)) continue;
        planned.add(
          _gateway.scheduleOnce(
            id: idFor(TrainingNotificationKind.dreamClue, at),
            at: at,
            title: 'Dream clue',
            body: 'A quiet cue from Oneiro — hearing this may mean you are '
                'dreaming. Do a reality check.',
            payload: TrainingPayloads.dreamClue,
            playSound: false,
          ),
        );
      }
    }
    return Future.wait(planned);
  }
}
