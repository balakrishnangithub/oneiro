import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/privacy/data/pin_repository.dart';
import 'package:oneiro/src/features/privacy/data/screen_privacy_service.dart';
import 'package:oneiro/src/features/privacy/presentation/privacy_section.dart';
import 'package:oneiro/src/features/privacy/privacy_providers.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';

import '../../support/fake_sync_services.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late InMemorySecureCredentialsStore secureStore;
  late PinRepository pinRepository;
  late OneiroDatabase db;
  late NoopScreenPrivacyService screenPrivacy;

  setUp(() {
    secureStore = InMemorySecureCredentialsStore();
    pinRepository = PinRepository(secureStore);
    db = createTestDatabase();
    screenPrivacy = NoopScreenPrivacyService();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() => ProviderScope(
    overrides: [
      secureCredentialsStoreProvider.overrideWithValue(secureStore),
      oneiroDatabaseProvider.overrideWithValue(db),
      screenPrivacyServiceProvider.overrideWithValue(screenPrivacy),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PrivacySection())),
    ),
  );

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  Future<void> drainSnackbars(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 5));

  /// PIN hashing/verifying now runs off the UI isolate (real async work the
  /// FakeAsync zone cannot advance). Alternate real event-loop windows with
  /// fake-zone pumps until [appear] shows, then settle.
  Future<void> pumpUntilAppears(WidgetTester tester, Finder appear) async {
    for (var i = 0; i < 40 && !tester.any(appear); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('enable flow: enter → confirm stores only a salted hash', (
    tester,
  ) async {
    await pumpSection(tester);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Journal opens freely'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'PIN lock'));
    await tester.pumpAndSettle();

    // Step 1: create.
    expect(find.text('Create a PIN'), findsOneWidget);
    // Continue stays disabled until the input is a valid 4–8 digit PIN.
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
      isFalse,
    );
    await tester.enterText(find.byType(TextField), '4471');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: confirm.
    expect(find.text('Confirm your PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '4471');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpUntilAppears(tester, find.text('PIN lock enabled'));

    expect(find.text('PIN lock enabled'), findsOneWidget);
    expect(find.text('Oneiro asks for your PIN on open'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);

    // Only the hash is stored — never the PIN itself.
    final stored = secureStore.values[PinRepository.hashKey];
    expect(stored, isNotNull);
    expect(stored, isNot(contains('4471')));
    expect(await tester.runAsync(() => pinRepository.verify('4471')), isTrue);
    expect(await tester.runAsync(() => pinRepository.verify('4472')), isFalse);

    await drainSnackbars(tester);
    await unmountApp(tester);
  });

  testWidgets('mismatched confirmation saves nothing', (tester) async {
    await pumpSection(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'PIN lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4471');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4472');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('PINs did not match — nothing was saved'), findsOneWidget);
    expect(secureStore.values.containsKey(PinRepository.hashKey), isFalse);
    // The switch is back to off.
    expect(find.text('Journal opens freely'), findsOneWidget);

    await drainSnackbars(tester);
    await unmountApp(tester);
  });

  testWidgets('disable requires the current PIN', (tester) async {
    await tester.runAsync(() => pinRepository.setPin('4471'));
    await pumpSection(tester);
    expect(find.text('Oneiro asks for your PIN on open'), findsOneWidget);

    // Wrong current PIN: stays enabled.
    await tester.tap(find.widgetWithText(SwitchListTile, 'PIN lock'));
    await tester.pumpAndSettle();
    expect(find.text('Disable PIN lock'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0000');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpUntilAppears(
      tester,
      find.text('Incorrect PIN — PIN lock stays on'),
    );
    expect(find.text('Incorrect PIN — PIN lock stays on'), findsOneWidget);
    expect(await pinRepository.isEnabled(), isTrue);
    await drainSnackbars(tester);

    // Correct current PIN: disabled and hash removed.
    await tester.tap(find.widgetWithText(SwitchListTile, 'PIN lock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4471');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpUntilAppears(tester, find.text('PIN lock disabled'));
    expect(find.text('PIN lock disabled'), findsOneWidget);
    expect(await pinRepository.isEnabled(), isFalse);
    expect(find.text('Journal opens freely'), findsOneWidget);

    await drainSnackbars(tester);
    await unmountApp(tester);
  });

  testWidgets('change PIN verifies current, then replaces the hash', (
    tester,
  ) async {
    await tester.runAsync(() => pinRepository.setPin('4471'));
    await pumpSection(tester);

    await tester.tap(find.text('Change PIN'));
    await tester.pumpAndSettle();
    // Current PIN.
    await tester.enterText(find.byType(TextField), '4471');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpUntilAppears(tester, find.text('Choose a new PIN'));
    // New PIN.
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '880123');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // Confirm new PIN.
    await tester.enterText(find.byType(TextField), '880123');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await pumpUntilAppears(tester, find.text('PIN changed'));

    expect(find.text('PIN changed'), findsOneWidget);
    expect(await tester.runAsync(() => pinRepository.verify('880123')), isTrue);
    expect(await tester.runAsync(() => pinRepository.verify('4471')), isFalse);

    await drainSnackbars(tester);
    await unmountApp(tester);
  });

  testWidgets('hide-in-switcher is on by default; toggling applies the flag', (
    tester,
  ) async {
    await pumpSection(tester);

    // Default ON before the user ever touches the switch.
    final tile = find.widgetWithText(SwitchListTile, 'Hide in app switcher');
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    // Turn it off: persisted and pushed to the platform immediately.
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(screenPrivacy.lastSecure, isFalse);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    // Turn it back on.
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(screenPrivacy.lastSecure, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await unmountApp(tester);
  });
}
