import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/sync/data/secure_credentials_store.dart';
import 'package:oneiro/src/features/sync/data/sync_settings_repository.dart';
import 'package:oneiro/src/features/sync/presentation/sync_section.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';

import '../../support/fake_sync_services.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;
  late InMemorySecureCredentialsStore secureStore;
  late DriftSyncSettingsRepository settingsRepository;

  setUp(() {
    db = createTestDatabase();
    secureStore = InMemorySecureCredentialsStore();
    settingsRepository = DriftSyncSettingsRepository(db);
  });

  tearDown(() async => db.close());

  late ProviderContainer container;

  Widget wrap() => ProviderScope(
    overrides: [
      oneiroDatabaseProvider.overrideWithValue(db),
      secureCredentialsStoreProvider.overrideWithValue(secureStore),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const SingleChildScrollView(child: SyncSection());
          },
        ),
      ),
    ),
  );

  Future<void> pumpSection(WidgetTester tester) async {
    // Tall surface: the section is long, and tests assert on controls a
    // phone-sized viewport would not build.
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  /// Creates a temp vault dir synchronously — widget-test bodies run in a
  /// FakeAsync zone where directly awaiting real dart:io futures deadlocks.
  Directory tempVaultDir() {
    final dir = Directory.systemTemp.createTempSync('oneiro_sync_widget');
    addTearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
    return dir;
  }

  /// Configures the local-folder backend pointing at [dir] through the UI.
  Future<void> configureLocalFolder(WidgetTester tester, Directory dir) async {
    await tester.tap(find.text('Local folder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Vault folder path'),
      dir.path,
    );
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders zero-knowledge explainer, locked state, never synced', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Encrypted Sync'), findsOneWidget);
    expect(find.textContaining('never sees your journal'), findsOneWidget);
    expect(find.textContaining('no one can recover it'), findsOneWidget);
    expect(find.text('WebDAV server'), findsOneWidget);
    expect(find.text('Local folder'), findsOneWidget);
    expect(find.text('Vault locked'), findsOneWidget);
    expect(find.text('Never synced'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('saving a WebDAV connection persists settings; password goes '
      'only to secure storage', (tester) async {
    await pumpSection(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Server URL'),
      'https://webdav.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      'dreamer',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      's3cret-app-password',
    );
    await tester.tap(find.text('Save connection'));
    await tester.pumpAndSettle();

    final settings = await settingsRepository.load();
    expect(settings.backendType, SyncBackendType.webdav);
    expect(settings.url, 'https://webdav.example.com');
    expect(settings.username, 'dreamer');
    expect(settings.basePath, '/oneiro-vault'); // default kept
    expect(
      secureStore.values[SecureCredentialKeys.syncPassword],
      's3cret-app-password',
    );

    // The password must not appear anywhere in app_settings.
    final rows = await db.select(db.appSettings).get();
    expect(
      rows.where((row) => row.value.contains('s3cret-app-password')),
      isEmpty,
    );

    await unmountApp(tester);
  });

  testWidgets('local folder backend persists and shows folder field', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.text('Local folder'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Vault folder path'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Server URL'), findsNothing);
    expect(
      (await settingsRepository.load()).backendType,
      SyncBackendType.localFolder,
    );

    await unmountApp(tester);
  });

  /// Taps [tap], then alternates real-time windows (so dart:io file I/O and
  /// the blocking scrypt derivation can make progress) with fake-zone pumps
  /// (so the queued async continuations and UI updates run), until [appear]
  /// is found or the ~8s budget is exhausted.
  ///
  /// Why: widget tests run in a FakeAsync zone where dart:io futures never
  /// complete on their own, and pumpAndSettle returns as soon as no frames
  /// are scheduled — long before real I/O has finished.
  Future<void> tapAndWaitFor(
    WidgetTester tester,
    Finder tap,
    Finder appear,
  ) async {
    await tester.tap(tap);
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      if (tester.any(appear)) return;
    }
    await tester.pumpAndSettle();
  }

  /// Forces the first build of the remote-store provider now (in the fake
  /// zone, where drift's stream timers run) so later reads resolve
  /// immediately from cached data.
  Future<void> warmUpSyncStore(WidgetTester tester) async {
    final future = container.read(remoteVaultStoreProvider.future);
    await tester.pumpAndSettle();
    await future;
    // Let any queued SnackBars (e.g. "Sync connection saved") expire so
    // later SnackBar assertions see the freshest message.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('unlock creates the vault, remembers the passphrase, lock '
      'forgets it again', (tester) async {
    final dir = tempVaultDir();
    await pumpSection(tester);
    await configureLocalFolder(tester, dir);
    await warmUpSyncStore(tester);

    // Strength hint reacts to the typed passphrase.
    await tester.enterText(
      find.widgetWithText(TextField, 'Vault passphrase'),
      'a very strong passphrase',
    );
    await tester.pump();
    expect(find.text('Strength: excellent'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Remember on this device'),
    );
    await tester.pumpAndSettle();

    await tapAndWaitFor(
      tester,
      find.text('Set / unlock'),
      find.widgetWithText(ListTile, 'Vault unlocked'),
    );

    expect(find.widgetWithText(ListTile, 'Vault unlocked'), findsOneWidget);
    expect(
      secureStore.values[SecureCredentialKeys.vaultPassphrase],
      'a very strong passphrase',
    );
    expect(File('${dir.path}/vault.json').existsSync(), isTrue);

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    expect(find.text('Vault locked'), findsOneWidget);
    expect(secureStore.values.containsKey('vault_passphrase'), isFalse);

    await unmountApp(tester);
  });

  testWidgets('sync now reports counts and, when locked, explains the lock', (
    tester,
  ) async {
    final dir = tempVaultDir();
    await pumpSection(tester);
    await configureLocalFolder(tester, dir);
    await warmUpSyncStore(tester);

    // Locked: sync now explains instead of failing.
    await tapAndWaitFor(
      tester,
      find.text('Sync now'),
      find.text('Vault is locked — unlock it to sync'),
    );
    expect(find.text('Vault is locked — unlock it to sync'), findsOneWidget);

    // Unlock (remember off → passphrase is not stored), then sync.
    await tester.enterText(
      find.widgetWithText(TextField, 'Vault passphrase'),
      'a very strong passphrase',
    );
    await tapAndWaitFor(
      tester,
      find.text('Set / unlock'),
      find.widgetWithText(ListTile, 'Vault unlocked'),
    );
    expect(secureStore.values.containsKey('vault_passphrase'), isFalse);

    await tapAndWaitFor(
      tester,
      find.text('Sync now'),
      find.textContaining('pushed 0, pulled 0'),
    );
    expect(
      find.textContaining('pushed 0, pulled 0, skipped 0'),
      findsOneWidget,
    );

    await unmountApp(tester);
  });

  testWidgets('sync holds a wake lock for the whole run', (tester) async {
    final wakeLock = FakeSyncWakeLock();
    final dir = tempVaultDir();
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oneiroDatabaseProvider.overrideWithValue(db),
          secureCredentialsStoreProvider.overrideWithValue(secureStore),
          syncWakeLockProvider.overrideWithValue(wakeLock),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const SingleChildScrollView(child: SyncSection());
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await configureLocalFolder(tester, dir);
    await warmUpSyncStore(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Vault passphrase'),
      'a very strong passphrase',
    );
    await tapAndWaitFor(
      tester,
      find.text('Set / unlock'),
      find.widgetWithText(ListTile, 'Vault unlocked'),
    );
    await tapAndWaitFor(
      tester,
      find.text('Sync now'),
      find.textContaining('pushed 0, pulled 0'),
    );

    expect(wakeLock.acquireCount, 1);
    expect(wakeLock.releaseCount, 1);

    await unmountApp(tester);
  });

  testWidgets('password fields offer a show/hide eye toggle', (tester) async {
    await pumpSection(tester);

    TextField passwordField() =>
        tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show').first);
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide').first);
    await tester.pump();
    expect(passwordField().obscureText, isTrue);

    await unmountApp(tester);
  });

  testWidgets('unlock drops the keyboard focus instead of jumping to the '
      'password field', (tester) async {
    final dir = tempVaultDir();
    await pumpSection(tester);
    await configureLocalFolder(tester, dir);
    await warmUpSyncStore(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Vault passphrase'),
      'a very strong passphrase',
    );
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tapAndWaitFor(
      tester,
      find.text('Set / unlock'),
      find.widgetWithText(ListTile, 'Vault unlocked'),
    );

    // No input field keeps focus: primary focus sits on the enclosing
    // Navigator scope (an EditableText would hold a plain FocusNode).
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

    await unmountApp(tester);
  });

  testWidgets('background sync is scheduled on remembered unlock and '
      'cancelled on lock', (tester) async {
    final scheduler = FakeBackgroundSyncScheduler();
    final dir = tempVaultDir();
    tester.view.physicalSize = const Size(1080, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oneiroDatabaseProvider.overrideWithValue(db),
          secureCredentialsStoreProvider.overrideWithValue(secureStore),
          backgroundSyncSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const SingleChildScrollView(child: SyncSection());
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await configureLocalFolder(tester, dir);
    await warmUpSyncStore(tester);

    // "Remember on this device" only renders while the vault is locked.
    Future<void> toggleRemember() async {
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Remember on this device'),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unlock() async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Vault passphrase'),
        'a very strong passphrase',
      );
      await tapAndWaitFor(
        tester,
        find.text('Set / unlock'),
        find.widgetWithText(ListTile, 'Vault unlocked'),
      );
    }

    // Toggling remember on schedules; toggling it back off cancels.
    await toggleRemember();
    expect(scheduler.ensureScheduledCount, 1);
    await toggleRemember();
    expect(scheduler.cancelCount, 1);

    // Unlock with remember OFF: background sync stays off (cancel re-armed).
    await unlock();
    expect(scheduler.ensureScheduledCount, 1);
    expect(scheduler.cancelCount, 2);

    // Locking the vault always cancels.
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    expect(scheduler.cancelCount, 3);

    // Unlock with remember ON schedules the periodic background sync.
    await toggleRemember();
    expect(scheduler.ensureScheduledCount, 2);
    await unlock();
    expect(scheduler.ensureScheduledCount, 3);
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    expect(scheduler.cancelCount, 4);

    await unmountApp(tester);
  });
}
