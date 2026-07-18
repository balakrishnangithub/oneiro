import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/privacy/presentation/app_lock_gate.dart';
import 'features/sync/sync_providers.dart';
import 'features/training/training_providers.dart';
import 'routing/app_router.dart';

class OneiroApp extends ConsumerWidget {
  const OneiroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Re-plans training notifications on startup and on every settings
    // change; a no-op until the settings stream first emits.
    ref.watch(trainingReplanProvider);
    // Attempts an app-start encrypted sync; a no-op unless sync is
    // configured and the vault passphrase is available. All failures are
    // swallowed inside the controller.
    ref.watch(autoSyncProvider);
    return MaterialApp.router(
      title: 'Oneiro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Blocks the shell behind the PIN lock screen whenever the app-lock
      // controller is locked (app start with a PIN, or background return).
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
