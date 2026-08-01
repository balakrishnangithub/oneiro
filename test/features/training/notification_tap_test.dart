import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneiro/src/features/training/data/notification_scheduler.dart';
import 'package:oneiro/src/features/training/training_providers.dart';
import 'package:oneiro/src/routing/app_router.dart';

void main() {
  /// Minimal stand-in for the app router: the same paths, stub pages.
  GoRouter buildRouter() => GoRouter(
    initialLocation: AppRoutes.journal,
    routes: [
      GoRoute(
        path: AppRoutes.journal,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.newDream,
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.realityCheck,
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  late GoRouter router;
  late ProviderContainer container;

  setUp(() {
    router = buildRouter();
    container = ProviderContainer(
      overrides: [appRouterProvider.overrideWithValue(router)],
    );
  });

  tearDown(() {
    container.dispose();
    router.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectOnTop(String path) {
    final config = router.routerDelegate.currentConfiguration;
    // Note: config.uri only reflects URL-driven navigation; the top match's
    // matchedLocation reflects imperative pushes too.
    expect(config.matches.last.matchedLocation, path);
    // The shell match sits underneath, so Done/back never empties the stack.
    expect(config.matches.length, greaterThan(1));
    expect(router.canPop(), isTrue);
  }

  testWidgets('a reality-check tap opens the ritual above the journal shell', (
    tester,
  ) async {
    await pumpApp(tester);

    await handleTrainingNotificationTap(
      container,
      TrainingPayloads.realityCheck,
    );
    await tester.pumpAndSettle();

    expectOnTop(AppRoutes.realityCheck);
  });

  testWidgets('a morning-reminder tap opens an empty dream editor above the '
      'shell', (tester) async {
    await pumpApp(tester);

    await handleTrainingNotificationTap(
      container,
      TrainingPayloads.morningReminder,
    );
    await tester.pumpAndSettle();

    expectOnTop(AppRoutes.newDream);
  });

  // The notification gateway delivers a launch tap during main(), before
  // runApp — the router is unattached, so the navigation must be deferred to
  // the first frame instead of being silently dropped.
  testWidgets('a cold-start reality-check tap opens the ritual after the '
      'first frame', (tester) async {
    expect(router.routerDelegate.currentConfiguration.isEmpty, isTrue);
    await handleTrainingNotificationTap(
      container,
      TrainingPayloads.realityCheck,
    );

    await pumpApp(tester);

    expectOnTop(AppRoutes.realityCheck);
  });

  testWidgets('a cold-start morning-reminder tap opens the editor after the '
      'first frame', (tester) async {
    expect(router.routerDelegate.currentConfiguration.isEmpty, isTrue);
    await handleTrainingNotificationTap(
      container,
      TrainingPayloads.morningReminder,
    );

    await pumpApp(tester);

    expectOnTop(AppRoutes.newDream);
  });
}
