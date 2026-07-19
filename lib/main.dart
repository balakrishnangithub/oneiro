import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/data/providers.dart';
import 'src/features/privacy/privacy_providers.dart';
import 'src/features/sync/background/background_sync.dart';
import 'src/features/training/data/notification_onboarding.dart';
import 'src/features/training/training_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container
      .read(notificationGatewayProvider)
      .initialize(
        onTap: (payload) => handleTrainingNotificationTap(container, payload),
      );

  // Reminders are on by default — ask for the notification runtime
  // permission on first launch (exactly once).
  await ensureNotificationPermissionRequestedOnce(
    db: container.read(oneiroDatabaseProvider),
    service: container.read(notificationPermissionServiceProvider),
  );

  // Register the WorkManager dispatcher so periodic sync can run while the
  // app is closed (Android only; defensive no-op elsewhere).
  await initializeBackgroundSync();

  // Apply the recents/screenshot privacy flag before the first frame
  // (default ON; Android-only, no-op elsewhere).
  final screenPrivacyRepo = container.read(screenPrivacyRepositoryProvider);
  await container
      .read(screenPrivacyServiceProvider)
      .setSecure(await screenPrivacyRepo.load());

  runApp(
    UncontrolledProviderScope(container: container, child: const OneiroApp()),
  );
}
