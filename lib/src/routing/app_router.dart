import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/journal/presentation/dream_editor_page.dart';
import '../features/journal/presentation/journal_page.dart';
import '../features/patterns/presentation/patterns_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class AppRoutes {
  static const journal = '/journal';
  static const patterns = '/patterns';
  static const progress = '/progress';
  static const settings = '/settings';
  static const newDream = '/journal/new';
  static String editDream(String id) => '/journal/$id/edit';
}

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.journal,
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
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DreamEditorPage(),
      ),
      GoRoute(
        path: '/journal/:id/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            DreamEditorPage(entryId: state.pathParameters['id']),
      ),
    ],
  ),
);
