import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/features/training/training_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await container
      .read(notificationGatewayProvider)
      .initialize(
        onTap: (payload) => handleTrainingNotificationTap(container, payload),
      );

  runApp(
    UncontrolledProviderScope(container: container, child: const OneiroApp()),
  );
}
