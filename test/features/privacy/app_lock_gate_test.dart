import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/journal/presentation/dream_editor_page.dart';
import 'package:oneiro/src/features/journal/presentation/journal_page.dart';
import 'package:oneiro/src/features/privacy/data/pin_repository.dart';
import 'package:oneiro/src/features/privacy/domain/pin_hasher.dart';
import 'package:oneiro/src/features/privacy/presentation/app_lock_gate.dart';
import 'package:oneiro/src/features/privacy/presentation/pin_lock_page.dart';
import 'package:oneiro/src/features/privacy/privacy_providers.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';
import 'package:oneiro/src/features/training/presentation/reality_check_page.dart';
import 'package:oneiro/src/routing/app_router.dart';

import '../../support/fake_sync_services.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late InMemorySecureCredentialsStore secureStore;
  late OneiroDatabase db;

  setUp(() {
    secureStore = InMemorySecureCredentialsStore();
    db = createTestDatabase();
  });

  tearDown(() async => db.close());

  Future<void> seedPin(String pin) async {
    secureStore.values[PinRepository.hashKey] = PinHasher.hash(pin);
  }

  Widget wrapApp() => ProviderScope(
    overrides: [
      oneiroDatabaseProvider.overrideWithValue(db),
      secureCredentialsStoreProvider.overrideWithValue(secureStore),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        routerConfig: ref.watch(appRouterProvider),
        builder: (context, child) =>
            AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    ),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapApp());
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AppLockGate)));

  Future<void> enterPin(WidgetTester tester, String pin) async {
    final container = containerOf(tester);
    final controller = container.read(appLockControllerProvider.notifier);
    final failuresBefore = controller.consecutiveFailures;
    for (final unit in pin.codeUnits) {
      await tester.tap(find.text(String.fromCharCode(unit)));
      await tester.pump();
    }
    // See pin_lock_page_test.dart — the verify runs off the UI isolate, so
    // alternate real event-loop windows with fake-zone pumps.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final state = container.read(appLockControllerProvider);
      if (state.status != AppLockStatus.locked ||
          controller.consecutiveFailures > failuresBefore) {
        break;
      }
    }
  }

  group('appLockRedirect policy', () {
    test('locked: protected routes go to /unlock', () {
      expect(
        appLockRedirect(AppRoutes.journal, AppLockStatus.locked),
        AppRoutes.unlock,
      );
      expect(
        appLockRedirect(AppRoutes.settings, AppLockStatus.locked),
        AppRoutes.unlock,
      );
      expect(
        appLockRedirect(AppRoutes.editDream('abc'), AppLockStatus.locked),
        AppRoutes.unlock,
      );
    });

    test('locked: notification routes and /unlock itself stay put', () {
      expect(
        appLockRedirect(AppRoutes.realityCheck, AppLockStatus.locked),
        isNull,
      );
      expect(appLockRedirect(AppRoutes.newDream, AppLockStatus.locked), isNull);
      expect(appLockRedirect(AppRoutes.unlock, AppLockStatus.locked), isNull);
    });

    test('unlocked: /unlock bounces to the journal, everything else stays', () {
      expect(
        appLockRedirect(AppRoutes.unlock, AppLockStatus.unlocked),
        AppRoutes.journal,
      );
      expect(
        appLockRedirect(AppRoutes.journal, AppLockStatus.unlocked),
        isNull,
      );
      expect(
        appLockRedirect(AppRoutes.editDream('abc'), AppLockStatus.unlocked),
        isNull,
      );
    });

    test(
      'checking: content routes pass through (the gate veils the flash)',
      () {
        expect(
          appLockRedirect(AppRoutes.journal, AppLockStatus.checking),
          isNull,
        );
      },
    );
  });

  testWidgets('locked cold start: the PIN screen shows and the journal '
      'never mounts', (tester) async {
    await seedPin('4471');
    await pumpApp(tester);

    expect(find.text('Oneiro is locked'), findsOneWidget);
    // Stronger than the old overlay: the journal route is never built.
    expect(find.byType(JournalPage), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('unlocking lands on the journal', (tester) async {
    await seedPin('4471');
    await pumpApp(tester);

    await enterPin(tester, '4471');
    await tester.pumpAndSettle();

    expect(find.text('Oneiro is locked'), findsNothing);
    expect(find.byType(JournalPage), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the reality-check ritual stays usable while locked, and Done '
      'returns to the PIN screen', (tester) async {
    await seedPin('4471');
    await pumpApp(tester);
    expect(find.text('Oneiro is locked'), findsOneWidget);

    containerOf(tester).read(appRouterProvider).push(AppRoutes.realityCheck);
    await tester.pumpAndSettle();
    expect(find.byType(RealityCheckPage), findsOneWidget);
    expect(find.text('Oneiro is locked'), findsNothing);

    await tester.tap(find.text("I'm awake"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(RealityCheckPage), findsNothing);
    expect(find.text('Oneiro is locked'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the empty dream editor stays usable while locked', (
    tester,
  ) async {
    await seedPin('4471');
    await pumpApp(tester);

    containerOf(tester).read(appRouterProvider).push(AppRoutes.newDream);
    await tester.pumpAndSettle();
    expect(find.byType(DreamEditorPage), findsOneWidget);
    expect(find.text('Oneiro is locked'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('backgrounding and resuming does NOT re-lock an unlocked '
      'session (cold start only)', (tester) async {
    await seedPin('4471');
    await pumpApp(tester);
    await enterPin(tester, '4471');
    await tester.pumpAndSettle();
    expect(find.byType(JournalPage), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      containerOf(tester).read(appLockControllerProvider).status,
      AppLockStatus.unlocked,
    );
    expect(find.byType(JournalPage), findsOneWidget);
    expect(find.text('Oneiro is locked'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('no PIN set: the journal shows immediately', (tester) async {
    await pumpApp(tester);

    expect(find.byType(JournalPage), findsOneWidget);
    expect(find.byType(PinLockPage), findsNothing);

    await unmountApp(tester);
  });
}
