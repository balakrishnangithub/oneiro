import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';
import '../data/remote_vault_store.dart';
import 'crypto/vault_crypto.dart';
import 'synced_entry.dart';

/// Outcome of one [SyncEngine.sync] run.
///
/// Per-file problems (corrupted remote envelopes, unreadable payloads,
/// transient I/O failures) never abort the run; they are collected in
/// [warnings] and the affected entry simply stays dirty for the next run.
class SyncReport {
  SyncReport({this.needsUnlock = false, this.syncedAt});

  /// Envelopes uploaded to the vault.
  int pushed = 0;

  /// Remote payloads applied to the local database.
  int pulled = 0;

  /// Entries changed on BOTH sides since the last sync; resolved
  /// last-write-wins by `updatedAt` (see `docs/sync-format.md`).
  int conflictsResolved = 0;

  /// Entries looked at but already in agreement.
  int skipped = 0;

  /// True when sync was requested but the vault is locked (no passphrase in
  /// memory). Nothing else in the report is meaningful then.
  bool needsUnlock;

  /// Human-readable per-file problems encountered during the run.
  final List<String> warnings = [];

  /// When the run finished (null when [needsUnlock]).
  DateTime? syncedAt;

  int get errorCount => warnings.length;

  @override
  String toString() => needsUnlock
      ? 'SyncReport(needsUnlock)'
      : 'SyncReport(pushed: $pushed, pulled: $pulled, '
            'conflicts: $conflictsResolved, skipped: $skipped, '
            'warnings: ${warnings.length})';
}

/// Replicates the local journal with an encrypted OVault remote.
///
/// The engine is pure Dart + drift: it talks to any [RemoteVaultStore] and
/// holds the unlocked [VaultCrypto] only in memory. Sync algorithm
/// (documented in `docs/sync-format.md`):
///
/// 1. **Push phase** — every local entry whose `updatedAt` differs from
///    `sync_state.lastSyncedUpdatedAt` (tombstones included) is compared
///    against the remote payload. If the remote side is newer, it wins and
///    is applied locally instead; otherwise the local entry is encrypted
///    and uploaded.
/// 2. **Pull phase** — remote files not touched by the push phase are
///    decrypted and applied when the local entry is missing or older.
/// 3. **Bookkeeping** — every successfully processed entry records the
///    winning `updatedAt` in `sync_state`, so unchanged entries are never
///    re-pushed.
///
/// **Conflict policy: last-write-wins by `updatedAt`.** When both sides
/// changed an entry since the last sync, the version with the larger
/// `updatedAt` is kept on both sides. Equal `updatedAt` is treated as
/// identical content.
class SyncEngine {
  SyncEngine({
    required OneiroDatabase db,
    required RemoteVaultStore store,
    VaultCrypto? crypto,
    DateTime Function()? clock,
  }) : _db = db,
       _store = store,
       _crypto = crypto,
       _now = clock ?? DateTime.now;

  final OneiroDatabase _db;
  final RemoteVaultStore _store;
  final DateTime Function() _now;

  VaultCrypto? _crypto;

  /// Whether a passphrase-derived key is currently held in memory.
  bool get isUnlocked => _crypto != null;

  /// The in-memory key, so callers can carry it across engine instances.
  VaultCrypto? get crypto => _crypto;

  /// Forgets the in-memory key. The passphrase must be entered (or restored
  /// from the platform credential vault) to sync again.
  void lock() => _crypto = null;

  /// First-run flow: creates the vault when the remote has no descriptor
  /// yet (generating a fresh salt and uploading `vault.json`), otherwise
  /// unlocks the existing vault.
  ///
  /// Throws [WrongPassphraseException] when the passphrase does not match an
  /// existing vault and [FormatException] on a malformed descriptor.
  Future<VaultCrypto> unlockOrCreateVault(String passphrase) async {
    await _store.ensureStructure();
    final descriptorText = await _store.readDescriptor();
    final VaultCrypto crypto;
    if (descriptorText == null) {
      final (descriptor, created) = await VaultCrypto.create(passphrase);
      await _store.writeDescriptor(descriptor.encode());
      crypto = created;
    } else {
      crypto = await VaultCrypto.unlock(
        passphrase,
        VaultDescriptor.decode(descriptorText),
      );
    }
    _crypto = crypto;
    return crypto;
  }

  /// Runs one full push+pull replication. Never throws on per-file
  /// corruption or I/O problems; see [SyncReport.warnings].
  Future<SyncReport> sync() async {
    final crypto = _crypto;
    if (crypto == null) {
      return SyncReport(needsUnlock: true);
    }
    final report = SyncReport(syncedAt: _now());

    await _store.ensureStructure();

    final localEntries = await _db.dreamEntryDao.getAllIncludingDeleted();
    final localById = {for (final entry in localEntries) entry.id: entry};
    final lastSyncedById = await _db.syncStateDao.getLastSyncedMap();
    final remoteIds = await _store.listEntryIds();
    final remoteIdSet = remoteIds.toSet();

    // Entries handled by the push phase; the pull phase skips them.
    final processed = <String>{};

    // --- Push phase: dirty local entries (including tombstones) -----------
    for (final entry in localEntries) {
      final lastSynced = lastSyncedById[entry.id];
      final isDirty = lastSynced == null || lastSynced != entry.updatedAt;
      if (!isDirty) continue;
      processed.add(entry.id);

      // Read the remote side first so last-write-wins never blindsides a
      // newer remote version.
      SyncedEntry? remote;
      if (remoteIdSet.contains(entry.id)) {
        final read = await _readRemote(crypto, entry.id, report);
        if (read.failed) {
          // Unreadable remote file: skip rather than clobber unknown data.
          continue;
        }
        remote = read.payload;
      }

      if (remote != null && remote.updatedAt > entry.updatedAt) {
        // Remote wins (last-write-wins).
        await _applyRemote(remote);
        await _db.syncStateDao.markSynced(entry.id, remote.updatedAt);
        report.pulled++;
        if (remote.updatedAt != lastSynced) report.conflictsResolved++;
      } else if (remote != null && remote.updatedAt == entry.updatedAt) {
        await _db.syncStateDao.markSynced(entry.id, entry.updatedAt);
        report.skipped++;
      } else {
        // Local wins (remote absent or older).
        try {
          final envelope = await crypto.encryptJson(
            SyncedEntry.fromEntry(entry).toJson(),
          );
          await _store.write(entry.id, envelope);
          await _db.syncStateDao.markSynced(entry.id, entry.updatedAt);
          report.pushed++;
          if (remote != null && remote.updatedAt != lastSynced) {
            report.conflictsResolved++;
          }
        } catch (error) {
          report.warnings.add('could not push entry ${entry.id}: $error');
        }
      }
    }

    // --- Pull phase: remote files the push phase did not handle -----------
    for (final id in remoteIds) {
      if (processed.contains(id)) continue;
      final read = await _readRemote(crypto, id, report);
      if (read.failed) continue;
      final payload = read.payload;
      if (payload == null) continue; // vanished between list and read

      final local = localById[id];
      if (local == null) {
        // Unknown locally: apply (a tombstone payload inserts a tombstone
        // row, so the deletion stays durable).
        await _applyRemote(payload);
        await _db.syncStateDao.markSynced(id, payload.updatedAt);
        report.pulled++;
      } else if (payload.updatedAt > local.updatedAt) {
        await _applyRemote(payload);
        await _db.syncStateDao.markSynced(id, payload.updatedAt);
        report.pulled++;
      } else {
        // Equal: already in agreement. Older-remote: the remote was rolled
        // back externally and the local entry is not dirty, so we keep the
        // local version without fighting the server (documented policy).
        if (payload.updatedAt == local.updatedAt &&
            lastSyncedById[id] != payload.updatedAt) {
          await _db.syncStateDao.markSynced(id, payload.updatedAt);
        }
        report.skipped++;
      }
    }

    return report;
  }

  /// Reads and decrypts one remote entry. Failures (I/O errors, corrupted
  /// envelopes) are recorded in [report.warnings] and flagged in the result
  /// so the caller can skip the entry without clobbering unknown data. A
  /// file that vanished between listing and reading is a quiet null.
  Future<({SyncedEntry? payload, bool failed})> _readRemote(
    VaultCrypto crypto,
    String id,
    SyncReport report,
  ) async {
    final Uint8List? bytes;
    try {
      bytes = await _store.read(id);
    } catch (error) {
      report.warnings.add('could not read remote entry $id: $error');
      return (payload: null, failed: true);
    }
    if (bytes == null) return (payload: null, failed: false);
    try {
      return (
        payload: SyncedEntry.fromJson(await crypto.decryptJson(bytes)),
        failed: false,
      );
    } catch (error) {
      report.warnings.add(
        'remote entry $id is corrupted or unreadable: $error',
      );
      return (payload: null, failed: true);
    }
  }

  /// Applies a remote payload verbatim, tombstone included.
  Future<void> _applyRemote(SyncedEntry payload) {
    return _db.dreamEntryDao.upsertFromSync(
      DreamEntriesCompanion(
        id: Value(payload.id),
        dreamDate: Value(payload.dreamDate),
        body: Value(payload.body),
        isLucid: Value(payload.isLucid),
        createdAt: Value(payload.createdAt),
        updatedAt: Value(payload.updatedAt),
        deletedAt: Value(payload.deletedAt),
      ),
    );
  }
}
