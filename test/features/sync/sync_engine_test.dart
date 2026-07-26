import 'dart:io';

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

  File archiveFile() => File('${vaultDir.path}/archive.bin');

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
    expect(pushReport.archiveUploaded, isTrue);
    expect(pushReport.needsUnlock, isFalse);

    await deviceB.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    final pullReport = await deviceB.engine.sync();
    expect(pullReport.pulled, count);
    expect(pullReport.pushed, 0);
    // Pure pull: the archive already held everything B needed.
    expect(pullReport.archiveUploaded, isFalse);
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

  test('dirty tracking: an unchanged vault is not re-uploaded', () async {
    await seedBothDevices(count: 2);
    final archiveAfterSeed = await archiveFile().readAsBytes();

    final againA = await deviceA.engine.sync();
    expect(againA.pushed, 0);
    expect(againA.pulled, 0);
    expect(againA.skipped, 2);
    expect(againA.archiveUploaded, isFalse);

    final againB = await deviceB.engine.sync();
    expect(againB.pushed, 0);
    expect(againB.pulled, 0);
    expect(againB.archiveUploaded, isFalse);

    // Byte-identical: no rewrite happened at all.
    expect(await archiveFile().readAsBytes(), archiveAfterSeed);
  });

  test('edit on B propagates back to A', () async {
    final entries = await seedBothDevices(count: 2);
    final edited = (await deviceB.repository.getById(entries[0].id))!;
    deviceB.nowMs = 2000;
    await deviceB.repository.updateEntry(edited.copyWith(body: 'edited on B'));

    final pushB = await deviceB.engine.sync();
    expect(pushB.pushed, 1);
    expect(pushB.archiveUploaded, isTrue);

    final pullA = await deviceA.engine.sync();
    expect(pullA.pulled, 1);
    expect(pullA.pushed, 0);
    expect(pullA.archiveUploaded, isFalse);
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
    expect(pushB.pushed, 0);
    expect(pushB.deletionsPushed, 1);

    final pullA = await deviceA.engine.sync();
    expect(pullA.pulled, 0);
    expect(pullA.deletionsPulled, 1);

    // Tombstoned on A: invisible to the journal, still present as a row.
    expect(
      (await deviceA.repository.getAllActive()).map((e) => e.id),
      isNot(contains(doomed.id)),
    );
    final tombstone = await deviceA.repository.getById(doomed.id);
    expect(tombstone!.deletedAt, 2000);
    expect(tombstone.updatedAt, 2000);

    // And the tombstone itself is now in sync (no further uploads).
    final again = await deviceA.engine.sync();
    expect(again.pushed, 0);
    expect(again.archiveUploaded, isFalse);
    expect(again.deletionsPulled, 0);
    expect(again.skipped, 1, reason: 'agreed tombstones are not "skipped"');
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

    expect(report.pulled, 2); // live entries only…
    expect(report.deletionsPulled, 1); // …the tombstone is reported apart
    expect(report.archiveUploaded, isFalse); // pure pull: nothing to upload
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
    expect(settled.deletionsPulled, 0);
    expect(settled.skipped, 2, reason: 'the agreed tombstone stays silent');
  });

  test('restore (undo delete) wins the entry back on every device', () async {
    final entries = await seedBothDevices(count: 2);
    final doomed = entries[0];

    // A deletes at t=2000; the tombstone reaches the vault and B.
    deviceA.nowMs = 2000;
    await deviceA.repository.softDelete(doomed.id);
    await deviceA.engine.sync();
    await deviceB.engine.sync();
    expect((await deviceB.repository.getById(doomed.id))!.deletedAt, 2000);

    // A taps undo at t=3000. The restore must bump updatedAt, otherwise the
    // merge sees "identical content" and the vault keeps the dream deleted
    // on every other device forever.
    deviceA.nowMs = 3000;
    await deviceA.repository.restore(doomed.id);
    final pushA = await deviceA.engine.sync();
    expect(pushA.pushed, 1);
    expect(pushA.deletionsPushed, 0);
    expect(pushA.archiveUploaded, isTrue);

    final pullB = await deviceB.engine.sync();
    expect(pullB.pulled, 1);
    final revived = (await deviceB.repository.getById(doomed.id))!;
    expect(revived.deletedAt, isNull);
    expect(revived.updatedAt, 3000);
    expect(
      (await deviceB.repository.getAllActive()).map((e) => e.id),
      contains(doomed.id),
    );
  });

  test(
    're-imported dreams under new ids collapse onto the vault ids',
    () async {
      // Field scenario: device A imported an Awoken file (random ids) and
      // pushed it; after a wipe the SAME file was imported again (new random
      // ids). Without content reconciliation the merge unions both id sets
      // and the journal doubles (366 + 366 = 732).
      await deviceA.engine.unlockOrCreateVault(passphrase, kdfN: 256);
      for (final body in ['dream alpha', 'dream beta', 'dream gamma']) {
        await deviceA.addEntry(body);
      }
      await deviceA.engine.sync();

      // The wiped/reinstalled device: same dreams, fresh random ids.
      final wiped = _Device(LocalDirectoryVaultStore(vaultDir.path));
      addTearDown(wiped.dispose);
      await wiped.engine.unlockOrCreateVault(passphrase, kdfN: 256);
      for (final body in ['dream alpha', 'dream beta', 'dream gamma']) {
        await wiped.addEntry(body);
      }

      final report = await wiped.engine.sync();
      expect(report.duplicatesCollapsed, 3);
      expect(report.pulled, 3, reason: 'the vault ids come down…');
      expect(report.pushed, 0, reason: '…not a second copy going up');

      // The journal shows each dream exactly once…
      final active = await wiped.repository.getAllActive();
      expect(active, hasLength(3));
      expect(active.map((e) => e.body).toSet(), {
        'dream alpha',
        'dream beta',
        'dream gamma',
      });
      // …and the duplicate local ids survive only as tombstones.
      expect(
        await wiped.db.dreamEntryDao.getAllIncludingDeleted(),
        hasLength(6),
      );

      // Steady state: nothing left to collapse or upload.
      final settled = await wiped.engine.sync();
      expect(settled.duplicatesCollapsed, 0);
      expect(settled.skipped, 3);
      expect(settled.archiveUploaded, isFalse);

      // The original device converges on the same 3 live entries (the
      // duplicate ids' tombstones replicate there too).
      await deviceA.engine.sync();
      expect(await deviceA.repository.getAllActive(), hasLength(3));
    },
  );

  test('corrupted archive is quarantined, rebuilt locally, then self-heals '
      'through the other device', () async {
    final entries = await seedBothDevices(count: 2);
    final clean = entries[1];

    // B makes a legitimate edit and uploads it.
    deviceB.nowMs = 2000;
    await deviceB.repository.updateEntry(
      (await deviceB.repository.getById(clean.id))!.copyWith(body: 'B edit'),
    );
    await deviceB.engine.sync();

    // The archive gets corrupted on the server (bit rot, bad client...).
    await archiveFile().writeAsString('garbage, not an envelope');

    // A syncs: the archive is unreadable → quarantined, NOT overwritten
    // silently; A rebuilds from its own state and warns the user.
    final report = await deviceA.engine.sync();
    expect(report.warnings, hasLength(1));
    expect(report.warnings.single, contains('unreadable'));
    expect(report.archiveUploaded, isTrue);
    expect(archiveFile().existsSync(), isTrue);
    expect(
      vaultDir.listSync().whereType<File>().where(
        (f) => f.path.contains('archive.corrupted-'),
      ),
      hasLength(1),
    );

    // B's edit survived on B; B's next sync re-merges it into the rebuilt
    // archive (B's version is newer than A's rebuilt content).
    final healB = await deviceB.engine.sync();
    expect(healB.archiveUploaded, isTrue);
    final healA = await deviceA.engine.sync();
    expect(healA.pulled, 1);
    expect((await deviceA.repository.getById(clean.id))!.body, 'B edit');
  });

  test('legacy v1 entries folder is removed once an archive exists', () async {
    // Simulate a vault that used the old per-entry format.
    final legacy = Directory('${vaultDir.path}/entries');
    await legacy.create(recursive: true);
    await File('${legacy.path}/old-id.json').writeAsString('old envelope');

    await deviceA.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    await deviceA.addEntry('dream');

    final events = <SyncProgress>[];
    await deviceA.engine.sync(onProgress: events.add);

    // The old folder is gone and the cleanup phase was reported.
    expect(legacy.existsSync(), isFalse);
    expect(events.map((e) => e.phase), contains(SyncPhase.cleaningUp));

    // Steady state: no legacy folder, no cleanup phase anymore.
    final steady = <SyncProgress>[];
    await deviceA.engine.sync(onProgress: steady.add);
    expect(steady.map((e) => e.phase), isNot(contains(SyncPhase.cleaningUp)));
  });

  test('progress walks download → merge → upload with entry counts', () async {
    await deviceA.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    for (var i = 0; i < 3; i++) {
      await deviceA.addEntry('dream $i');
    }

    final pushEvents = <SyncProgress>[];
    final pushReport = await deviceA.engine.sync(onProgress: pushEvents.add);
    expect(pushReport.pushed, 3);
    expect(pushEvents.map((e) => (e.phase, e.processed, e.total)).toList(), [
      (SyncPhase.downloading, 0, 1),
      (SyncPhase.downloading, 1, 1),
      (SyncPhase.merging, 1, 3),
      (SyncPhase.merging, 2, 3),
      (SyncPhase.merging, 3, 3),
      (SyncPhase.uploading, 0, 1),
      (SyncPhase.uploading, 1, 1),
    ]);

    // A second device pulling the same vault merges but uploads nothing.
    await deviceB.engine.unlockOrCreateVault(passphrase, kdfN: 256);
    final pullEvents = <SyncProgress>[];
    final pullReport = await deviceB.engine.sync(onProgress: pullEvents.add);
    expect(pullReport.pulled, 3);
    expect(pullEvents.map((e) => (e.phase, e.processed, e.total)).toList(), [
      (SyncPhase.downloading, 0, 1),
      (SyncPhase.downloading, 1, 1),
      (SyncPhase.merging, 1, 3),
      (SyncPhase.merging, 2, 3),
      (SyncPhase.merging, 3, 3),
    ]);

    // Nothing dirty anywhere: merge confirms agreement, no upload phase.
    final idleEvents = <SyncProgress>[];
    final idleReport = await deviceA.engine.sync(onProgress: idleEvents.add);
    expect(idleReport.pushed, 0);
    expect(idleReport.pulled, 0);
    expect(idleReport.skipped, 3);
    expect(idleEvents.map((e) => (e.phase, e.processed, e.total)).toList(), [
      (SyncPhase.downloading, 0, 1),
      (SyncPhase.downloading, 1, 1),
      (SyncPhase.merging, 1, 3),
      (SyncPhase.merging, 2, 3),
      (SyncPhase.merging, 3, 3),
    ]);
  });
}
