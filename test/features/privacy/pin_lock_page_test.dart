import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/privacy/data/pin_repository.dart';
import 'package:oneiro/src/features/privacy/domain/pin_hasher.dart';
import 'package:oneiro/src/features/privacy/presentation/app_lock_gate.dart';
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
    child: const MaterialApp(
      home: AppLockGate(child: Scaffold(body: Text('Journal content'))),
    ),
  );

  Future<void> seedPin(String pin) async {
    secureStore.values[PinRepository.hashKey] = PinHasher.hash(pin);
  }

  /// Roomy surface: the whole PIN pad is on screen and nothing scrolls.
  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final unit in pin.codeUnits) {
      await tester.tap(find.text(String.fromCharCode(unit)));
      await tester.pump();
    }
    // Let the async verify + state flip land.
    await tester.pump();
  }

  testWidgets('no PIN set: the shell is never gated', (tester) async {
    await pumpGate(tester);

    expect(find.text('Journal content'), findsOneWidget);
    expect(find.text('Oneiro is locked'), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('locked state shows the PIN pad over the shell', (tester) async {
    await seedPin('4471');
    await pumpGate(tester);

    expect(find.text('Oneiro is locked'), findsOneWidget);
    expect(
      find.text('Enter your PIN to open your journal'),
      findsOneWidget,
    );
    // The shell stays in the tree (navigation state preserved) but is
    // covered by the opaque lock page.
    expect(find.text('Journal content'), findsOneWidget);
    // Four dots for a four-digit PIN.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('the correct PIN unlocks the shell', (tester) async {
    await seedPin('4471');
    await pumpGate(tester);
    expect(find.text('Oneiro is locked'), findsOneWidget);

    await enterPin(tester, '4471');
    await tester.pumpAndSettle();

    expect(find.text('Oneiro is locked'), findsNothing);
    expect(find.text('Journal content'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('a wrong PIN shows an error, clears the dots, and does not '
      'unlock', (tester) async {
    await seedPin('4471');
    await pumpGate(tester);

    await enterPin(tester, '0000');
    await tester.pumpAndSettle();

    expect(find.text('Oneiro is locked'), findsOneWidget);
    expect(find.text('Incorrect PIN — 4 attempts left'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('five wrong PINs start a 30-second cooldown that the injected '
      'clock can end', (tester) async {
    await seedPin('4471');
    await pumpGate(tester);

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
    expect(find.text('Oneiro is locked'), findsNothing);
    expect(find.text('Journal content'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('backgrounding the app re-locks an unlocked session',
      (tester) async {
    await seedPin('4471');
    await pumpGate(tester);
    await enterPin(tester, '4471');
    await tester.pumpAndSettle();
    expect(find.text('Oneiro is locked'), findsNothing);

    late ProviderContainer container;
    final context = tester.element(find.text('Journal content'));
    container = ProviderScope.containerOf(context);

    // The state flips immediately on pause. (While paused the scheduler
    // disables frames — exactly like a real device — so the overlay itself
    // is drawn on the first frame after resume.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.locked,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Oneiro is locked'), findsOneWidget);

    await unmountApp(tester);
  });
}
