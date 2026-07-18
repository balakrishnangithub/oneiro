import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Runtime notification-permission flow (Android 13+ requires
/// POST_NOTIFICATIONS to be granted at runtime).
///
/// Behind an interface so widget tests can fake both the status and the
/// request outcome.
abstract class NotificationPermissionService {
  /// Whether the app may currently post notifications.
  Future<bool> isGranted();

  /// Shows the system permission prompt; returns the resulting grant state.
  Future<bool> request();
}

/// [NotificationPermissionService] backed by `flutter_local_notifications`.
class FlutterNotificationPermissionService
    implements NotificationPermissionService {
  FlutterNotificationPermissionService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isGranted() async => await _android?.areNotificationsEnabled() ?? true;

  @override
  Future<bool> request() async =>
      await _android?.requestNotificationsPermission() ?? true;
}
