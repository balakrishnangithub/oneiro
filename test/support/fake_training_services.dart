import 'package:oneiro/src/features/training/data/notification_gateway.dart';
import 'package:oneiro/src/features/training/data/notification_permission_service.dart';
import 'package:oneiro/src/features/training/domain/clue_player.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';

/// One notification the OS was asked to schedule.
class ScheduledNotification {
  ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    this.at,
    this.minutesOfDay,
    this.playSound = true,
    this.daily = false,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
  final DateTime? at;
  final int? minutesOfDay;
  final bool playSound;
  final bool daily;
}

/// Records every call; no plugin involvement.
class FakeNotificationGateway implements NotificationGateway {
  bool initialized = false;
  int cancelCount = 0;
  final List<ScheduledNotification> scheduled = [];
  void Function(String? payload)? onTap;

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async {
    initialized = true;
    this.onTap = onTap ?? this.onTap;
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    scheduled.clear();
  }

  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    bool playSound = true,
  }) async {
    scheduled.add(
      ScheduledNotification(
        id: id,
        at: at,
        title: title,
        body: body,
        payload: payload,
        playSound: playSound,
      ),
    );
  }

  @override
  Future<void> scheduleDaily({
    required int id,
    required int minutesOfDay,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled.add(
      ScheduledNotification(
        id: id,
        minutesOfDay: minutesOfDay,
        title: title,
        body: body,
        payload: payload,
        daily: true,
      ),
    );
  }
}

/// Records totem plays instead of touching the audio plugin.
class FakeCluePlayer implements CluePlayer {
  final List<(TotemSound, double)> plays = [];

  @override
  Future<void> play(TotemSound sound, double volume) async {
    plays.add((sound, volume));
  }
}

/// Controllable permission flow for widget tests.
class FakeNotificationPermissionService
    implements NotificationPermissionService {
  FakeNotificationPermissionService({this.granted = true});

  bool granted;
  int requestCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCount++;
    return granted;
  }
}
