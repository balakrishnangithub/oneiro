import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../privacy_providers.dart';

/// Startup veil: covers the app with a blank night-indigo surface while the
/// credential vault is being read at cold start, so journal content never
/// flashes before the PIN lock engages.
///
/// Locking itself is NOT enforced here — it is enforced by the router (see
/// `appLockRedirect` in app_router.dart): while [AppLockController] is
/// locked, every route outside `publicRoutesWhileLocked` redirects to
/// /unlock, and the PIN screen is a normal route with proper Navigator
/// ancestry. The lock engages on cold start ONLY; switching to another app
/// and coming back does not re-lock (the recents-privacy flag, on by
/// default, already blanks the app-switcher snapshot).
///
/// Widget tests are unaffected unless they opt in: pages pumped directly
/// never mount this veil.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appLockControllerProvider).status;
    if (status == AppLockStatus.checking) {
      return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    }
    return child;
  }
}
