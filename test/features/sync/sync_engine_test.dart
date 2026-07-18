import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/repositories/dream_repository.dart';
import 'package:oneiro/src/features/sync/data/local_directory_vault_store.dart';
import 'package:oneiro/src/features/sync/domain/crypto/vault_crypto.dart';
import 'package:oneiro/src/features/sync/domain/sync_engine.dart';

import '../../support/test_database.dart';

/// One simulated device: its own in-memory database, a repository and a
/// sync engine, all sharing one controllable clock.
class _Device {
  _Device(this.store, {int startMs = 1000}) : nowMs = startMs {
    db = createTestDatabase();
    repository = DriftDreamRepository(db.dreamEntryDao, clock: clock);
    engine = SyncEngine(db: db, store: store, clock: clock);
  }

  final LocalDirectoryVaultStore store;
  late final OneiroDatabase db;
  late final DriftDreamRepository repository;
  late final SyncEngine engine;
  int nowMs;

  DateTime clock() => DateTime.fromMillisecondsSinceEpoch(nowMs);

  Future<DreamEntry> addEntry(String body, {bool isLucid = false}) {
    return repository.createEntry(
      dreamDate: DateTime.fromMillisecondsSinceEpoch(1778457600000),
      text: body,
      isLucid: isLucid,
    );
  }

  Future<void> dispose() => db.close();
}

void main() {
  const passphrase = 'correct horse battery staple';

  // The two simulated devices intentionally run two OneiroDatabase
  // instances side by side — each on its own in-memory executor, so the
  // multiple-instances warning is a false positive here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory vaultDir;
  late _Device deviceA;
  late _Device deviceB;

  setUp(() async {
    vaultDir = await Directory.systemTemp.createTemp('oneiro_sync_e2e');
    deviceA = _Device(LocalDirectoryVaultStore(vaultDir.path));
    deviceB = _Device(LocalDirectoryVaultStore(vaultDir.path));
  });

  tearDown(() async {
    await deviceA.dispose();
    await deviceB.dispose();
    if (vaultDir.existsSync()) await vaultDir.delete(recursive: true);
  });

  /// Creates a vault on A with [count] entries and syncs both devices to a
  /// common state. Returns the entries as created on A.
  Future<List<DreamEntry>> seedBothDevices({int count = 2}) async {
    await deviceA.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    final entries = <DreamEntry>[
      for (var i = 0; i < count; i++)
        await deviceA.addEntry('dream $i', isLucid: i.isOdd),
    ];
    final pushReport = await deviceA.engine.sync();
    expect(pushReport.pushed, count);
    expect(pushReport.needsUnlock, isFalse);

    await deviceB.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    final pullReport = await deviceB.engine.sync();
    expect(pullReport.pulled, count);
    expect(pullReport.pushed, 0);
    return entries;
  }

  test('sync without an unlocked vault reports needsUnlock', () async {
    final report = await deviceA.engine.sync();
    expect(report.needsUnlock, isTrue);
    expect(report.pushed, 0);
    expect(report.pulled, 0);
    expect(report.warnings, isEmpty);
  });

  test('first run creates the vault; a wrong passphrase is rejected', () async {
    await deviceA.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    expect(deviceA.engine.isUnlocked, isTrue);
    expect(File('${vaultDir.path}/vault.json').existsSync(), isTrue);

    // A second device unlocks the same vault instead of recreating it.
    await deviceB.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    expect(deviceB.engine.isUnlocked, isTrue);

    await expectLater(
      _Device(
        LocalDirectoryVaultStore(vaultDir.path),
      ).engine.unlockOrCreateVault('wrong passphrase', kdfN: 256),
      throwsA(isA<WrongPassphraseException>()),
    );
  });

  test('push from A then pull into B replicates entries', () async {
    final entries = await seedBothDevices(count: 3);

    final onB = await deviceB.repository.getAllActive();
    expect(onB, hasLength(3));
    expect(onB.map((e) => e.id).toSet(), entries.map((e) => e.id).toSet());
    expect(onB.firstWhere((e) => e.id == entries[1].id).isLucid, isTrue);
    expect(onB.firstWhere((e) => e.id == entries[0].id).body, 'dream 0');
    // createdAt/updatedAt replicate verbatim.
    expect(onB.firstWhere((e) => e.id == entries[0].id).createdAt, 1000);
  });

  test('dirty tracking: unchanged entries are not re-pushed', () async {
    await seedBothDevices(count: 2);

    final againA = await deviceA.engine.sync();
    expect(againA.pushed, 0);
    expect(againA.pulled, 0);
    expect(againA.skipped, 2);

    final againB = await deviceB.engine.sync();
    expect(againB.pushed, 0);
    expect(againB.pulled, 0);
  });

  test('edit on B propagates back to A', () async {
    final entries = await seedBothDevices(count: 2);
    final edited = (await deviceB.repository.getById(entries[0].id))!;
    deviceB.nowMs = 2000;
    await deviceB.repository.updateEntry(edited.copyWith(body: 'edited on B'));

    final pushB = await deviceB.engine.sync();
    expect(pushB.pushed, 1);

    final pullA = await deviceA.engine.sync();
    expect(pullA.pulled, 1);
    expect(pullA.pushed, 0);
    final onA = await deviceA.repository.getById(entries[0].id);
    expect(onA!.body, 'edited on B');
    expect(onA.updatedAt, 2000);
  });

  test(
    'conflict: newer remote edit wins over older local edit (LWW)',
    () async {
      final entries = await seedBothDevices(count: 1);
      final id = entries.single.id;

      // A edits at t=2000, B edits later at t=3000; B syncs first.
      deviceA.nowMs = 2000;
      await deviceA.repository.updateEntry(
        (await deviceA.repository.getById(id))!.copyWith(body: 'A version'),
      );
      deviceB.nowMs = 3000;
      await deviceB.repository.updateEntry(
        (await deviceB.repository.getById(id))!.copyWith(body: 'B version'),
      );
      final pushB = await deviceB.engine.sync();
      expect(pushB.pushed, 1);
      expect(pushB.conflictsResolved, 0); // remote was unchanged: plain push

      // A now syncs: local is dirty, but B's version is newer → remote wins.
      final syncA = await deviceA.engine.sync();
      expect(syncA.pushed, 0);
      expect(syncA.pulled, 1);
      expect(syncA.conflictsResolved, 1);
      expect((await deviceA.repository.getById(id))!.body, 'B version');
      expect((await deviceA.repository.getById(id))!.updatedAt, 3000);

      // And once more in the other direction: A's newer edit (t=4000) beats
      // B's older one (t=3500) even though B pushes first.
      deviceA.nowMs = 4000;
      await deviceA.repository.updateEntry(
        (await deviceA.repository.getById(id))!.copyWith(body: 'A newer'),
      );
      deviceB.nowMs = 3500;
      await deviceB.repository.updateEntry(
        (await deviceB.repository.getById(id))!.copyWith(body: 'B older'),
      );
      await deviceB.engine
          .sync(); // pushes 3500 (remote was clean: no conflict)
      final syncA2 = await deviceA.engine.sync();
      expect(syncA2.pushed, 1); // A's 4000 wins and is uploaded
      expect(syncA2.conflictsResolved, 1);
      final syncB2 = await deviceB.engine.sync();
      expect(syncB2.pulled, 1);
      expect((await deviceB.repository.getById(id))!.body, 'A newer');
    },
  );

  test('deletion on B propagates to A as a tombstone', () async {
    final entries = await seedBothDevices(count: 2);
    final doomed = entries[0];

    deviceB.nowMs = 2000;
    await deviceB.repository.softDelete(doomed.id);
    final pushB = await deviceB.engine.sync();
    expect(pushB.pushed, 1);

    final pullA = await deviceA.engine.sync();
    expect(pullA.pulled, 1);

    // Tombstoned on A: invisible to the journal, still present as a row.
    expect(
      (await deviceA.repository.getAllActive()).map((e) => e.id),
      isNot(contains(doomed.id)),
    );
    final tombstone = await deviceA.repository.getById(doomed.id);
    expect(tombstone!.deletedAt, 2000);
    expect(tombstone.updatedAt, 2000);

    // And the tombstone itself is now in sync (no further pushes).
    final again = await deviceA.engine.sync();
    expect(again.pushed, 0);
  });

  test('wipe-and-restore: a fresh device rebuilds the journal', () async {
    final entries = await seedBothDevices(count: 3);
    deviceB.nowMs = 2000;
    await deviceB.repository.softDelete(entries[2].id);
    await deviceB.engine.sync();

    // Simulate a wiped/reinstalled device: brand-new empty database.
    final restored = _Device(LocalDirectoryVaultStore(vaultDir.path));
    addTearDown(restored.dispose);
    await restored.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    final report = await restored.engine.sync();

    expect(report.pulled, 3); // two live entries + one tombstone
    final active = await restored.repository.getAllActive();
    expect(active.map((e) => e.id).toSet(), {entries[0].id, entries[1].id});
    expect(
      (await restored.repository.getById(entries[2].id))!.deletedAt,
      isNotNull,
    );

    // Fully in sync afterwards: nothing left to push or pull.
    final settled = await restored.engine.sync();
    expect(settled.pushed, 0);
    expect(settled.pulled, 0);
    expect(settled.skipped, 3);
  });

  test(
    'corrupted remote file warns, sync continues, entry stays dirty',
    () async {
      final entries = await seedBothDevices(count: 2);
      final corrupted = entries[0];
      final clean = entries[1];

      // Corrupt one remote file and make a legit remote change to the other.
      await deviceA.store.write(
        corrupted.id,
        Uint8List.fromList('garbage, not json'.codeUnits),
      );
      deviceB.nowMs = 2000;
      await deviceB.repository.updateEntry(
        (await deviceB.repository.getById(clean.id))!.copyWith(body: 'B edit'),
      );
      await deviceB.engine.sync();

      final report = await deviceA.engine.sync();
      expect(report.warnings, hasLength(1));
      expect(report.warnings.single, contains(corrupted.id));
      expect(report.pulled, 1); // the clean entry still replicated
      expect((await deviceA.repository.getById(clean.id))!.body, 'B edit');

      // The corrupted entry was not marked synced, so a later run retries it.
      final states = await deviceA.db.syncStateDao.getLastSyncedMap();
      expect(states[corrupted.id], 1000);
      expect(states[clean.id], 2000);

      // A dirty local entry is NOT clobbered over a corrupted remote file.
      deviceA.nowMs = 3000;
      await deviceA.repository.updateEntry(
        (await deviceA.repository.getById(
          corrupted.id,
        ))!.copyWith(body: 'A local edit'),
      );
      final blocked = await deviceA.engine.sync();
      expect(blocked.warnings, isNotEmpty);
      expect(blocked.pushed, 0);
      // The corrupted remote bytes are still there, untouched.
      final raw = await deviceA.store.read(corrupted.id);
      expect(String.fromCharCodes(raw!), 'garbage, not json');
    },
  );
}
