import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/settings/presentation/settings_page.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/training_providers.dart';

import '../../support/fake_sync_services.dart';
import '../../support/fake_training_services.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;
  late DriftSettingsRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [
        oneiroDatabaseProvider.overrideWithValue(db),
        notificationGatewayProvider.overrideWithValue(
          FakeNotificationGateway(),
        ),
        cluePlayerProvider.overrideWithValue(FakeCluePlayer()),
        notificationPermissionServiceProvider.overrideWithValue(
          FakeNotificationPermissionService(granted: false),
        ),
        // The Privacy section reads the credential vault; never let widget
        // tests touch the real plugin.
        secureCredentialsStoreProvider.overrideWithValue(
          InMemorySecureCredentialsStore(),
        ),
      ],
      child: const MaterialApp(home: SettingsPage()),
    );
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    // Tall surface: the ListView is lazy, and tests assert on tiles that a
    // phone-sized viewport would not have built yet.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = createTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  testWidgets('shows all training sections', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Reality checks'), findsOneWidget);
    expect(find.text('Dream clues'), findsOneWidget);
    expect(find.text('Morning journal reminder'), findsOneWidget);
    expect(find.text('Training pause'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    // Stage F section; ensureVisible because the ListView builds lazily.
    await tester.ensureVisible(find.text('Privacy'));
    expect(find.text('Privacy'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('toggling daytime reminders persists', (tester) async {
    await pumpSettings(tester);

    final tile = find.widgetWithText(SwitchListTile, 'Daytime reminders');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect((await repository.load()).realityChecksEnabled, isFalse);

    await unmountApp(tester);
  });

  testWidgets('toggling night-time audio cues persists', (tester) async {
    await pumpSettings(tester);

    final tile = find.widgetWithText(SwitchListTile, 'Night-time audio cues');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect((await repository.load()).dreamCluesEnabled, isTrue);

    await unmountApp(tester);
  });

  testWidgets('pausing training sets pausedUntil and resume clears it', (
    tester,
  ) async {
    await pumpSettings(tester);

    final pauseButton = find.text('Pause 3 days');
    await tester.ensureVisible(pauseButton);
    await tester.tap(pauseButton);
    await tester.pumpAndSettle();

    expect((await repository.load()).pausedUntil, isNotNull);
    expect(find.text('Training is paused'), findsOneWidget);

    await tester.ensureVisible(find.text('Resume training'));
    await tester.tap(find.text('Resume training'));
    await tester.pumpAndSettle();

    expect((await repository.load()).pausedUntil, isNull);

    await unmountApp(tester);
  });

  testWidgets('shows blocked-permission row and offers a request button', (
    tester,
  ) async {
    await pumpSettings(tester);

    final row = find.text('Notifications are blocked');
    await tester.ensureVisible(row);
    expect(row, findsOneWidget);
    expect(find.text('Request'), findsOneWidget);

    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();

    await unmountApp(tester);
  });
}
