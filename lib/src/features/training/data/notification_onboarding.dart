import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';
import 'notification_permission_service.dart';

/// Key in `app_settings` recording that the system notification-permission
/// prompt was already shown once.
const notificationPermissionRequestedKey = 'notification_permission_requested';

/// Asks for the notification runtime permission exactly once.
///
/// Reality-check and dream-clue reminders are on by default, so the best
/// moment to ask is the first app start. After that first attempt the system
/// decides (Android shows its own rationale/denied behaviour); the app never
/// spams the prompt on later launches — the Settings page keeps a manual
/// request row instead.
///
/// No-op when permission is already granted (or the platform needs none).
Future<void> ensureNotificationPermissionRequestedOnce({
  required OneiroDatabase db,
  required NotificationPermissionService service,
}) async {
  if (await service.isGranted()) return;

  final existing =
      await (db.select(
            db.appSettings,
          )..where((row) => row.key.equals(notificationPermissionRequestedKey)))
          .getSingleOrNull();
  if (existing != null) return;

  await service.request();
  await db
      .into(db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion(
          key: const Value(notificationPermissionRequestedKey),
          value: const Value('true'),
        ),
      );
}
