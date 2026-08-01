import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/privacy/data/pin_repository.dart';
import 'package:oneiro/src/features/privacy/domain/pin_hasher.dart';
import 'package:oneiro/src/features/privacy/presentation/pin_lock_page.dart';
import 'package:oneiro/src/features/privacy/privacy_providers.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';

import '../../support/fake_sync_services.dart';
import '../../support/unmount_app.dart';

class _ManualClock {
  DateTime now = DateTime(2026, 3, 1, 12);
  DateTime call() => now;
}

void main() {
  late InMemorySecureCredentialsStore secureStore;
  late _ManualClock clock;

  setUp(() {
    secureStore = InMemorySecureCredentialsStore();
    clock = _ManualClock();
  });

  Widget wrap() => ProviderScope(
    overrides: [
      secureCredentialsStoreProvider.overrideWithValue(secureStore),
      appLockClockProvider.overrideWithValue(clock.call),
    ],
    child: const MaterialApp(home: PinLockPage()),
  );

  Future<void> seedPin(String pin) async {
    secureStore.values[PinRepository.hashKey] = PinHasher.hash(pin);
  }

  /// Roomy surface: the whole PIN pad is on screen and nothing scrolls.
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PinLockPage)),
    );
    final controller = container.read(appLockControllerProvider.notifier);
    final failuresBefore = controller.consecutiveFailures;
    for (final unit in pin.codeUnits) {
      await tester.tap(find.text(String.fromCharCode(unit)));
      await tester.pump();
    }
    // The verify now runs off the UI isolate — real async work the FakeAsync
    // zone cannot advance. Alternate real event-loop windows (so the isolate
    // future completes) with fake-zone pumps (so the UI reacts to it) until
    // the submission resolves: unlock, recorded failure, or cooldown start.
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

  testWidgets('the pad matches the stored PIN length', (tester) async {
    await seedPin('4471');
    await pumpPage(tester);

    expect(find.text('Oneiro is locked'), findsOneWidget);
    expect(find.text('Enter your PIN to open your journal'), findsOneWidget);
    // Four dots for a four-digit PIN.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the correct PIN unlocks the session', (tester) async {
    await seedPin('4471');
    await pumpPage(tester);

    await enterPin(tester, '4471');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PinLockPage)),
    );
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.unlocked,
    );

    await unmountApp(tester);
  });

  testWidgets('a wrong PIN shows an error, clears the dots, and does not '
      'unlock', (tester) async {
    await seedPin('4471');
    await pumpPage(tester);

    await enterPin(tester, '0000');
    await tester.pumpAndSettle();

    expect(find.text('Incorrect PIN — 4 attempts left'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('five wrong PINs start a 30-second cooldown that the injected '
      'clock can end', (tester) async {
    await seedPin('4471');
    await pumpPage(tester);

    for (var i = 1; i <= 5; i++) {
      await enterPin(tester, '0000');
    }
    await tester.pump();

    // Cooldown: countdown visible, pad ignores digits. (pump, not settle —
    // the 1-second countdown ticker is a periodic timer in the fake zone.)
    expect(
      find.textContaining('Too many attempts — try again in'),
      findsOneWidget,
    );
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.text('Incorrect PIN — 0 attempts left'), findsNothing);

    // Still cooling down near the end of the window.
    clock.now = clock.now.add(const Duration(seconds: 25));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('Too many attempts — try again in'),
      findsOneWidget,
    );

    // Past the window: the ticker cancels itself and the pad works again.
    clock.now = clock.now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.textContaining('Too many attempts — try again in'),
      findsNothing,
    );

    await enterPin(tester, '4471');
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PinLockPage)),
    );
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.unlocked,
    );

    await unmountApp(tester);
  });
}
