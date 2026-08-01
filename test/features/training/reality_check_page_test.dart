import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/presentation/reality_check_page.dart';
import 'package:oneiro/src/routing/app_router.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;
  late DriftSettingsRepository repository;
  late GoRouter router;

  GoRouter buildRouter() => GoRouter(
    initialLocation: AppRoutes.realityCheck,
    routes: [
      GoRoute(
        path: AppRoutes.journal,
        builder: (context, state) => const Scaffold(body: Text('Journal stub')),
      ),
      GoRoute(
        path: AppRoutes.realityCheck,
        builder: (context, state) => const RealityCheckPage(),
      ),
    ],
  );

  Widget wrap() {
    return ProviderScope(
      overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  setUp(() {
    db = createTestDatabase();
    repository = DriftSettingsRepository(db);
    router = buildRouter();
  });

  tearDown(() async {
    router.dispose();
    await db.close();
  });

  testWidgets('"I\'m awake" increments the counter and confirms', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm awake"));
    await tester.pumpAndSettle();

    expect(await repository.realityCheckCount(), 1);
    expect(find.text('Logged.'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('"I was dreaming" also counts as a completed check', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I was dreaming'));
    await tester.pumpAndSettle();

    expect(await repository.realityCheckCount(), 1);
    expect(find.text('Logged.'), findsOneWidget);

    await unmountApp(tester);
  });

  // Regression: tapping Done when the ritual is the app's only route (cold
  // start straight from the notification) must land on the journal, not pop
  // the last route into a black screen.
  testWidgets('Done with nothing underneath lands on the journal', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byType(RealityCheckPage), findsOneWidget);
    expect(router.canPop(), isFalse);

    await tester.tap(find.text("I'm awake"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(RealityCheckPage), findsNothing);
    expect(find.text('Journal stub'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the back button with nothing underneath also lands on the '
      'journal', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RealityCheckPage), findsNothing);
    expect(find.text('Journal stub'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('Done with a route underneath pops back to it', (tester) async {
    router.go(AppRoutes.journal);
    router.push(AppRoutes.realityCheck);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byType(RealityCheckPage), findsOneWidget);

    await tester.tap(find.text('I was dreaming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(RealityCheckPage), findsNothing);
    expect(find.text('Journal stub'), findsOneWidget);

    await unmountApp(tester);
  });
}
