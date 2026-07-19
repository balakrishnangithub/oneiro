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
  FlutterNotificationPermissionService([
    FlutterLocalNotificationsPlugin? plugin,
  ]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isGranted() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }
    // iOS/macOS expose no permission-status API through the plugin; the
    // onboarding flow requests once and the system remembers the choice.
    return true;
  }

  @override
  Future<bool> request() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
    }
    // macOS and future platforms: nothing to ask for here.
    return true;
  }
}
