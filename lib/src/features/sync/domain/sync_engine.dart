import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';
import '../data/remote_vault_store.dart';
import 'crypto/vault_archive.dart';
import 'crypto/vault_crypto.dart';
import 'synced_entry.dart';

/// Outcome of one [SyncEngine.sync] run.
///
/// A corrupted remote archive never aborts the run silently: it is
/// quarantined, reported in [warnings], and rebuilt from local data.
class SyncReport {
  SyncReport({this.needsUnlock = false, this.syncedAt});

  /// Locally changed entries whose content went up in the uploaded archive.
  int pushed = 0;

  /// Remote payloads applied to the local database during the merge.
  int pulled = 0;

  /// Entries changed on BOTH sides since the last sync; resolved
  /// last-write-wins by `updatedAt` (see `docs/sync-format.md`).
  int conflictsResolved = 0;

  /// Entries found already in agreement during the merge. Tombstones in
  /// agreement are not counted here — [skipped] tracks live dreams only,
  /// so it always matches what the journal list shows.
  int skipped = 0;

  /// Remote tombstones applied locally — dreams deleted on another device.
  /// Counted apart from [pulled] so the numbers match what the journal
  /// actually gains: pulling a vault of 373 dreams plus 3 tombstones reads
  /// "pulled 373, 3 deletions", not "pulled 376".
  int deletionsPulled = 0;

  /// Local tombstones carried by the uploaded archive — dreams deleted on
  /// this device since the last sync.
  int deletionsPushed = 0;

  /// Whether the merged archive was (re)uploaded this run.
  bool archiveUploaded = false;

  /// True when sync was requested but the vault is locked (no passphrase in
  /// memory). Nothing else in the report is meaningful then.
  bool needsUnlock;

  /// Human-readable problems encountered during the run.
  final List<String> warnings = [];

  /// When the run finished (null when [needsUnlock]).
  DateTime? syncedAt;

  int get errorCount => warnings.length;

  @override
  String toString() => needsUnlock
      ? 'SyncReport(needsUnlock)'
      : 'SyncReport(pushed: $pushed, pulled: $pulled, '
            'deletionsPushed: $deletionsPushed, '
            'deletionsPulled: $deletionsPulled, '
            'conflicts: $conflictsResolved, skipped: $skipped, '
            'archiveUploaded: $archiveUploaded, '
            'warnings: ${warnings.length})';
}

/// Which step of a sync run is currently active.
enum SyncPhase {
  /// Fetching and decrypting the remote archive.
  downloading,

  /// Merging remote entries with the local database (per-entry counts).
  merging,

  /// Building and atomically uploading the merged archive.
  uploading,

  /// Removing legacy v1 per-entry files after a successful migration.
  cleaningUp,
}

/// Live progress of one [SyncEngine.sync] run.
class SyncProgress {
  const SyncProgress({
    required this.phase,
    required this.processed,
    required this.total,
  });

  /// The step currently working.
  final SyncPhase phase;

  /// Units handled so far in this phase (1-based once work starts).
  final int processed;

  /// Units to handle in this phase. 1 for whole-file phases
  /// (download/upload/cleanup), the merged-entry count for
  /// [SyncPhase.merging].
  final int total;
}

/// Replicates the local journal with an encrypted OVault v2 remote.
///
/// The engine is pure Dart + drift: it talks to any [RemoteVaultStore] and
/// holds the unlocked [VaultCrypto] only in memory. Sync algorithm
/// (documented in `docs/sync-format.md`):
///
/// 1. **Download** — fetch `archive.bin` (if any) and decrypt it into the
///    remote entry set. A corrupted archive is quarantined and treated as
///    empty, never overwritten blindly.
/// 2. **Merge** — walk the union of local and remote ids. The side with the
///    newer `updatedAt` wins (last-write-wins); remote winners are applied
///    to the local database immediately.
/// 3. **Upload** — only when the merged state differs from the remote
///    archive, re-encode the full local state (winners, tombstones
///    included), encrypt it and upload atomically. Pure-pull runs and
///    no-change runs upload nothing.
/// 4. **Cleanup** — once a v2 archive exists remotely, legacy v1 per-entry
///    files are removed.
///
/// **Conflict policy: last-write-wins by `updatedAt`.** Equal `updatedAt`
/// is treated as identical content. Because every sync merges the full
/// state, a lost upload race heals itself on the next run.
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
  ///
  /// [kdfN] overrides the scrypt cost parameter only when CREATING a new
  /// vault — tests pass a small value to stay fast. Unlocking always honors
  /// the parameters recorded in the remote descriptor.
  Future<VaultCrypto> unlockOrCreateVault(
    String passphrase, {
    int kdfN = VaultCrypto.defaultKdfN,
  }) async {
    await _store.ensureStructure();
    final descriptorText = await _store.readDescriptor();
    final VaultCrypto crypto;
    if (descriptorText == null) {
      final (descriptor, created) = await VaultCrypto.create(
        passphrase,
        kdfN: kdfN,
      );
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

  /// Runs one full download+merge+upload replication.
  ///
  /// [onProgress] fires at phase boundaries and per merged entry, so callers
  /// can show "Merging 45/377…" style feedback.
  Future<SyncReport> sync({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final crypto = _crypto;
    if (crypto == null) {
      return SyncReport(needsUnlock: true);
    }
    final report = SyncReport(syncedAt: _now());

    await _store.ensureStructure();

    // --- 1. Download -------------------------------------------------------
    onProgress?.call(
      const SyncProgress(phase: SyncPhase.downloading, processed: 0, total: 1),
    );
    final archiveBytes = await _store.readArchive();
    var remoteById = <String, SyncedEntry>{};
    var archivePresent = archiveBytes != null;
    if (archiveBytes != null) {
      try {
        remoteById = {
          for (final entry in VaultArchive.decode(
            await crypto.decryptBytes(archiveBytes),
          ))
            entry.id: entry,
        };
      } catch (error) {
        // Never overwrite unknown data: move the unreadable archive aside
        // and rebuild from local state below.
        report.warnings.add(
          'remote archive was unreadable ($error) — moved aside and '
          'rebuilt from local data',
        );
        try {
          await _store.quarantineArchive();
        } catch (quarantineError) {
          report.warnings.add(
            'could not quarantine the corrupted archive: $quarantineError',
          );
        }
        archivePresent = false;
      }
    }
    onProgress?.call(
      const SyncProgress(phase: SyncPhase.downloading, processed: 1, total: 1),
    );

    // --- 2. Merge ----------------------------------------------------------
    final localEntries = await _db.dreamEntryDao.getAllIncludingDeleted();
    final localById = {for (final entry in localEntries) entry.id: entry};
    final lastSyncedById = await _db.syncStateDao.getLastSyncedMap();

    final unionIds = <String>{...localById.keys, ...remoteById.keys}.toList()
      ..sort();

    final winners = <String, SyncedEntry>{};
    var uploadNeeded = false;
    var merged = 0;
    for (final id in unionIds) {
      final local = localById[id];
      final remote = remoteById[id];
      final lastSynced = lastSyncedById[id];
      final localDirty = local != null && lastSynced != local.updatedAt;

      if (local == null && remote != null) {
        // Unknown locally: apply (a tombstone payload inserts a tombstone
        // row, so the deletion stays durable).
        winners[id] = remote;
        await _applyRemote(remote);
        await _db.syncStateDao.markSynced(id, remote.updatedAt);
        if (remote.deletedAt != null) {
          report.deletionsPulled++;
        } else {
          report.pulled++;
        }
      } else if (local != null && remote == null) {
        // Only local has it: it must reach the archive.
        winners[id] = SyncedEntry.fromEntry(local);
        uploadNeeded = true;
        if (localDirty) {
          if (local.deletedAt != null) {
            report.deletionsPushed++;
          } else {
            report.pushed++;
          }
        }
      } else if (local != null && remote != null) {
        if (remote.updatedAt > local.updatedAt) {
          // Remote wins (last-write-wins).
          winners[id] = remote;
          await _applyRemote(remote);
          await _db.syncStateDao.markSynced(id, remote.updatedAt);
          if (remote.deletedAt != null) {
            report.deletionsPulled++;
          } else {
            report.pulled++;
          }
          if (localDirty) report.conflictsResolved++;
        } else {
          winners[id] = SyncedEntry.fromEntry(local);
          if (remote.updatedAt < local.updatedAt) {
            // Local wins: the archive must be refreshed.
            uploadNeeded = true;
            if (localDirty) {
              if (local.deletedAt != null) {
                report.deletionsPushed++;
              } else {
                report.pushed++;
              }
            }
            if (lastSynced != null && lastSynced != remote.updatedAt) {
              report.conflictsResolved++;
            }
          } else {
            // Identical timestamps: treated as identical content. Agreed
            // tombstones stay uncounted — "skipped" mirrors the journal.
            if (local.deletedAt == null) report.skipped++;
            if (lastSynced != local.updatedAt) {
              await _db.syncStateDao.markSynced(id, local.updatedAt);
            }
          }
        }
      }
      merged++;
      onProgress?.call(
        SyncProgress(
          phase: SyncPhase.merging,
          processed: merged,
          total: unionIds.length,
        ),
      );
    }
    // A quarantined (or never created) archive must be rebuilt whenever the
    // merged state has anything worth storing.
    if (!archivePresent && winners.isNotEmpty) uploadNeeded = true;

    // --- 3. Upload ---------------------------------------------------------
    var archiveUploaded = false;
    if (uploadNeeded) {
      onProgress?.call(
        const SyncProgress(phase: SyncPhase.uploading, processed: 0, total: 1),
      );
      final envelope = await crypto.encryptBytes(
        VaultArchive.encode(winners.values),
      );
      await _store.writeArchiveAtomic(envelope);
      archiveUploaded = true;
      report.archiveUploaded = true;
      // Local winners only become "synced" once the archive carrying them
      // is safely stored.
      for (final id in unionIds) {
        final local = localById[id];
        final winner = winners[id];
        if (local != null &&
            winner != null &&
            winner.updatedAt == local.updatedAt &&
            lastSyncedById[id] != local.updatedAt) {
          await _db.syncStateDao.markSynced(id, local.updatedAt);
        }
      }
      onProgress?.call(
        const SyncProgress(phase: SyncPhase.uploading, processed: 1, total: 1),
      );
    }

    // --- 4. Legacy cleanup ---------------------------------------------------
    // Only once a v2 archive is in place: the old per-entry files must never
    // be the only copy that disappears.
    if (archivePresent || archiveUploaded) {
      try {
        final removed = await _store.deleteLegacyEntries();
        if (removed) {
          onProgress?.call(
            const SyncProgress(
              phase: SyncPhase.cleaningUp,
              processed: 1,
              total: 1,
            ),
          );
        }
      } catch (error) {
        report.warnings.add('could not remove legacy entry files: $error');
      }
    }

    return report;
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
