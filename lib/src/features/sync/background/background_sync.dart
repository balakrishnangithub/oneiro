import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../../data/db/oneiro_database.dart';
import '../data/secure_credentials_store.dart';
import '../data/sync_settings_repository.dart';
import '../data/vault_store_factory.dart';
import '../domain/crypto/vault_crypto.dart';
import '../domain/sync_engine.dart';

/// Unique WorkManager task name for Oneiro's periodic background sync.
const backgroundSyncTaskName = 'io.github.lightbala.oneiro.periodic-sync';

/// Unique WorkManager task name for the one-off continuation enqueued when
/// a foreground sync is interrupted (app backgrounded, screen off).
const backgroundSyncOnceTaskName = 'io.github.lightbala.oneiro.sync-once';

/// How often Android wakes the app for a background sync. WorkManager may
/// defer this further under doze/battery pressure — it is a safety net on top
/// of app-start auto-sync, not a real-time channel.
const backgroundSyncFrequency = Duration(hours: 6);

/// WorkManager entry point. Runs in a background isolate spawned by Android
/// while the app is closed (screen locked, app swiped away). Plugin
/// registration in that isolate is handled by the workmanager plugin itself.
///
/// Must stay a top-level function with the vm:entry-point pragma so AOT
/// compilation keeps it reachable from native code.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    OneiroDatabase? db;
    try {
      db = OneiroDatabase();
      return await runBackgroundSync(
        db: db,
        secure: FlutterSecureCredentialsStore(),
      );
    } catch (error) {
      debugPrint('Oneiro: background sync failed, will retry: $error');
      return false; // transient failure → WorkManager retries with backoff
    } finally {
      await db?.close();
    }
  });
}

/// One background sync attempt against already-resolved platform services.
///
/// Kept free of plugin globals so tests can drive it with an in-memory
/// database and fakes. Returns true when the attempt is finished (retries
/// would not help): sync not configured, no remembered passphrase, or a wrong
/// passphrase. Returns false only for failures worth retrying.
Future<bool> runBackgroundSync({
  required OneiroDatabase db,
  required SecureCredentialsStore secure,
}) async {
  final settings = await DriftSyncSettingsRepository(db).load();
  if (!settings.isConfigured) return true;

  final passphrase = await secure.read(SecureCredentialKeys.vaultPassphrase);
  if (passphrase == null || passphrase.isEmpty) {
    // Vault locked and not remembered on this device: quiet no-op.
    return true;
  }

  final store = await buildRemoteVaultStore(settings, secure);
  if (store == null) return true;

  final engine = SyncEngine(db: db, store: store);
  try {
    await engine.unlockOrCreateVault(passphrase);
  } on WrongPassphraseException {
    // Permanent until the user re-unlocks; retrying would loop forever.
    return true;
  }
  final report = await engine.sync();
  if (!report.needsUnlock) {
    final settingsRepository = DriftSyncSettingsRepository(db);
    final syncedAt = report.syncedAt;
    if (syncedAt != null) {
      await settingsRepository.recordSyncAt(syncedAt);
      await settingsRepository.recordRunSummary(
        SyncRunSummary(
          pushed: report.pushed,
          pulled: report.pulled,
          deletions: report.deletionsPulled + report.deletionsPushed,
          deduplicated: report.duplicatesCollapsed,
          conflictsResolved: report.conflictsResolved,
          warningCount: report.warnings.length,
          background: true,
          finishedAt: syncedAt,
        ),
      );
    }
  }
  debugPrint('Oneiro: background sync finished — $report');
  return true;
}

/// Schedules (or cancels) the periodic background sync task.
///
/// Behind an interface so tests can record scheduling without a platform
/// channel. Only Android is wired today; other platforms are deliberate
/// no-ops (iOS BGTaskScheduler support is future work — the interface and
/// call sites already allow it).
abstract class BackgroundSyncScheduler {
  /// Registers the periodic task if absent; keeps the existing one
  /// otherwise. Safe to call on every app start / unlock.
  Future<void> ensureScheduled();

  /// Removes the periodic task (vault locked, "remember" turned off).
  Future<void> cancel();

  /// Enqueues a single background sync as soon as constraints allow.
  ///
  /// Used when a foreground sync is interrupted (app backgrounded, screen
  /// turned off): WorkManager holds a system wake lock and finishes the
  /// job even if the process is frozen. Only meaningful with a remembered
  /// passphrase — without one the background isolate cannot unlock.
  Future<void> runOnce();
}

/// [BackgroundSyncScheduler] backed by Android WorkManager.
class WorkmanagerBackgroundSyncScheduler implements BackgroundSyncScheduler {
  @override
  Future<void> ensureScheduled() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      backgroundSyncTaskName,
      backgroundSyncTaskName,
      frequency: backgroundSyncFrequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(backgroundSyncTaskName);
  }

  @override
  Future<void> runOnce() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerOneOffTask(
      backgroundSyncOnceTaskName,
      backgroundSyncOnceTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}

/// Initializes WorkManager with Oneiro's dispatcher. Call once at app start;
/// a no-op off Android. Kept tiny and defensive — a scheduling failure must
/// never block startup.
Future<void> initializeBackgroundSync() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(backgroundSyncCallbackDispatcher);
  } catch (error) {
    debugPrint('Oneiro: background sync initialization failed: $error');
  }
}
