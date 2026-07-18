import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/data/providers.dart';
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

  runApp(
    UncontrolledProviderScope(container: container, child: const OneiroApp()),
  );
}
