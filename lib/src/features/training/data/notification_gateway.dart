import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin abstraction over the local-notifications plugin.
///
/// All planning logic lives in pure Dart (`NotificationScheduler`); this
/// gateway only knows how to put notifications on (and take them off) the
/// OS schedule. Tests substitute a fake that records calls.
abstract class NotificationGateway {
  /// Idempotent plugin + timezone initialization.
  ///
  /// [onTap] receives the payload of a tapped notification, including the
  /// one that launched the app from a terminated state.
  Future<void> initialize({void Function(String? payload)? onTap});

  /// Cancels everything previously scheduled by this app.
  Future<void> cancelAll();

  /// Schedules a one-shot notification at [at] (local wall-clock time).
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
    bool playSound = true,
  });

  /// Schedules a notification that repeats daily at [minutesOfDay].
  Future<void> scheduleDaily({
    required int id,
    required int minutesOfDay,
    required String title,
    required String body,
    required String payload,
  });
}

/// [NotificationGateway] backed by `flutter_local_notifications`.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Fall back to the UTC location; scheduling still works, only DST
      // handling may differ from the device's zone.
      debugPrint('Oneiro: could not resolve device timezone ($e); using UTC');
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Permission prompts are owned by the onboarding flow, so the plugin
      // must not ask again at initialize time.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) =>
          onTap?.call(response.payload),
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      onTap?.call(launch?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  NotificationDetails _details({required bool playSound}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'oneiro_training',
          'Training reminders',
          channelDescription:
              'Reality checks, dream clues and the morning journal prompt',
          importance: playSound ? Importance.high : Importance.low,
          priority: playSound ? Priority.high : Priority.low,
          playSound: playSound,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
        macOS: DarwinNotificationDetails(presentSound: playSound),
      );

  /// Picks the Android schedule mode the OS will actually accept.
  ///
  /// On Android 14+ the SCHEDULE_EXACT_ALARM special permission is DENIED by
  /// default, and `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`
  /// then throws a PlatformException — which historically meant zero
  /// notifications were ever scheduled (the failure was swallowed upstream).
  /// When exact alarms are not granted we fall back to
  /// [AndroidScheduleMode.inexactAllowWhileIdle]: the reminder may arrive a
  /// few minutes off, but scheduling NEVER throws just because exact alarms
  /// are denied. Null (non-Android platform / plugin unavailable) defaults
  /// to exact, matching pre-check behavior on platforms without the concept.
  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? true;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
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
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(playSound: playSound),
      androidScheduleMode: await _scheduleMode(),
      payload: payload,
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
    final now = DateTime.now();
    var next = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(minutes: minutesOfDay));
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(next, tz.local),
      notificationDetails: _details(playSound: false),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }
}
