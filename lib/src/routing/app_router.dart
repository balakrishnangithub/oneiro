import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/journal/presentation/dream_editor_page.dart';
import '../features/journal/presentation/journal_page.dart';
import '../features/patterns/presentation/patterns_page.dart';
import '../features/privacy/presentation/pin_lock_page.dart';
import '../features/privacy/privacy_providers.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/training/presentation/reality_check_page.dart';
import 'app_shell.dart';

/// Root navigator key — used to open pages above the shell from outside the
/// widget tree (e.g. from a tapped notification).
final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class AppRoutes {
  static const journal = '/journal';
  static const patterns = '/patterns';
  static const progress = '/progress';
  static const settings = '/settings';
  static const newDream = '/journal/new';
  static const realityCheck = '/reality-check';
  static const unlock = '/unlock';
  static String editDream(String id) => '/journal/$id/edit';
}

/// Routes that stay reachable while the journal is locked.
///
/// These are exactly the screens a training notification can deep-link into,
/// and none of them reveal stored journal content or settings:
///
/// - [AppRoutes.realityCheck]: the ritual is content-free,
/// - [AppRoutes.newDream]: an empty editor — writing a brand-new entry does
///   not expose anything already stored.
///
/// [AppRoutes.editDream] is deliberately NOT here: it reveals an existing
/// entry, so it stays behind the PIN. The moment navigation leaves this
/// list (finishing the ritual, saving or discarding the new dream, pressing
/// back) the redirect sends the user to [AppRoutes.unlock].
const publicRoutesWhileLocked = {AppRoutes.realityCheck, AppRoutes.newDream};

/// The PIN-lock guard, applied as the router's redirect.
///
/// - locked: everything except [publicRoutesWhileLocked] (and the unlock
///   page itself) goes to [AppRoutes.unlock],
/// - checking/unlocked: [AppRoutes.unlock] never lingers — it bounces to
///   the journal.
///
/// Pure and string-based so the policy is unit-testable without a router.
@visibleForTesting
String? appLockRedirect(String matchedLocation, AppLockStatus status) {
  final onUnlockPage = matchedLocation == AppRoutes.unlock;
  switch (status) {
    case AppLockStatus.locked:
      if (onUnlockPage || publicRoutesWhileLocked.contains(matchedLocation)) {
        return null;
      }
      return AppRoutes.unlock;
    case AppLockStatus.checking:
    case AppLockStatus.unlocked:
      return onUnlockPage ? AppRoutes.journal : null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-runs the redirect whenever the lock state flips: unlocking leaves
  // /unlock for the journal; a future "lock now" drops to /unlock.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(appLockControllerProvider, (previous, next) => refresh.value++);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.journal,
    refreshListenable: refresh,
    redirect: (context, state) => appLockRedirect(
      state.matchedLocation,
      ref.read(appLockControllerProvider).status,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.journal,
                builder: (context, state) => const JournalPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.patterns,
                builder: (context, state) => const PatternsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen editor routes, above the navigation shell.
      GoRoute(
        path: AppRoutes.newDream,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const DreamEditorPage(),
      ),
      GoRoute(
        path: '/journal/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            DreamEditorPage(entryId: state.pathParameters['id']),
      ),
      // Reality-check ritual, opened from training notifications.
      GoRoute(
        path: AppRoutes.realityCheck,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RealityCheckPage(),
      ),
      // PIN lock, reached via redirect whenever the session is locked.
      GoRoute(
        path: AppRoutes.unlock,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PinLockPage(),
      ),
    ],
  );
});
