import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/features/sync/background/background_sync.dart';
import 'package:oneiro/src/features/sync/data/secure_credentials_store.dart';
import 'package:oneiro/src/features/sync/data/sync_settings_repository.dart';

import '../../support/fake_sync_services.dart';
import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late InMemorySecureCredentialsStore secure;
  late DriftSyncSettingsRepository settingsRepository;
  late Directory vaultDir;

  setUp(() async {
    db = createTestDatabase();
    secure = InMemorySecureCredentialsStore();
    settingsRepository = DriftSyncSettingsRepository(db);
    vaultDir = await Directory.systemTemp.createTemp('oneiro_bg_sync');
  });

  tearDown(() async {
    await db.close();
    if (vaultDir.existsSync()) await vaultDir.delete(recursive: true);
  });

  Future<void> configureLocalFolder({bool remember = true}) {
    return settingsRepository.save(
      SyncConnectionSettings(
        backendType: SyncBackendType.localFolder,
        localFolderPath: vaultDir.path,
        rememberPassphrase: remember,
      ),
    );
  }

  test('unconfigured sync is a quiet success (no retry storm)', () async {
    expect(await runBackgroundSync(db: db, secure: secure), isTrue);
  });

  test('locked vault (no remembered passphrase) is a quiet no-op', () async {
    await configureLocalFolder();
    await db.dreamEntryDao.insertEntry(
      buildEntry(id: 'a', dreamDate: DateTime(2026, 7, 20), text: 'dream'),
    );

    expect(await runBackgroundSync(db: db, secure: secure), isTrue);
    // Nothing was uploaded: the entries folder was never created.
    expect(Directory('${vaultDir.path}/entries').existsSync(), isFalse);
  });

  test(
    'remembered passphrase syncs end-to-end and records lastSyncAt',
    () async {
      await configureLocalFolder();
      secure.values[SecureCredentialKeys.vaultPassphrase] =
          'a very strong passphrase';
      await db.dreamEntryDao.insertEntry(
        buildEntry(
          id: 'a',
          dreamDate: DateTime(2026, 7, 20),
          text: 'dream one',
        ),
      );
      await db.dreamEntryDao.insertEntry(
        buildEntry(
          id: 'b',
          dreamDate: DateTime(2026, 7, 21),
          text: 'dream two',
          isLucid: true,
        ),
      );

      expect(await runBackgroundSync(db: db, secure: secure), isTrue);

      // Both entries were encrypted and uploaded; the descriptor exists.
      final entriesDir = Directory('${vaultDir.path}/entries');
      expect(entriesDir.listSync().whereType<File>().length, 2);
      expect(File('${vaultDir.path}/vault.json').existsSync(), isTrue);
      expect(await settingsRepository.lastSyncAt(), isNotNull);

      // Dirty flags cleared: a second run uploads nothing new.
      final before = entriesDir.listSync().length;
      expect(await runBackgroundSync(db: db, secure: secure), isTrue);
      expect(entriesDir.listSync().length, before);
    },
  );

  test('a wrong remembered passphrase does not retry (returns true)', () async {
    await configureLocalFolder();
    // First create the vault with the right passphrase.
    secure.values[SecureCredentialKeys.vaultPassphrase] = 'right passphrase';
    expect(await runBackgroundSync(db: db, secure: secure), isTrue);

    // Then simulate a stale/wrong remembered passphrase.
    secure.values[SecureCredentialKeys.vaultPassphrase] = 'wrong passphrase';
    expect(await runBackgroundSync(db: db, secure: secure), isTrue);
  });
}
