import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'background/background_sync.dart';
import 'data/remote_vault_store.dart';
import 'data/secure_credentials_store.dart';
import 'data/sync_settings_repository.dart';
import 'data/sync_wake_lock.dart';
import 'data/vault_store_factory.dart';
import 'domain/crypto/vault_crypto.dart';
import 'domain/sync_engine.dart';

/// Platform credential vault for sync secrets; faked in tests.
final secureCredentialsStoreProvider = Provider<SecureCredentialsStore>(
  (ref) => FlutterSecureCredentialsStore(),
);

/// Keeps the device awake during a sync run; faked in tests.
final syncWakeLockProvider = Provider<SyncWakeLock>(
  (ref) => WakelockPlusSyncWakeLock(),
);

/// Schedules the WorkManager periodic background sync; faked in tests.
final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>(
  (ref) => WorkmanagerBackgroundSyncScheduler(),
);

/// Typed façade over the `app_settings` keys owned by the sync feature.
final syncSettingsRepositoryProvider = Provider<SyncSettingsRepository>(
  (ref) => DriftSyncSettingsRepository(ref.watch(oneiroDatabaseProvider)),
);

/// Live sync connection settings, re-emitting on every change.
final syncConnectionSettingsProvider = StreamProvider<SyncConnectionSettings>(
  (ref) => ref.watch(syncSettingsRepositoryProvider).watch(),
);

/// Builds the store for the current settings, or null when sync is not
/// configured yet. WebDAV passwords come from the credential vault, never
/// from drift.
final remoteVaultStoreProvider = FutureProvider<RemoteVaultStore?>((ref) async {
  final settings = await ref.watch(syncConnectionSettingsProvider.future);
  final secure = ref.watch(secureCredentialsStoreProvider);
  return buildRemoteVaultStore(settings, secure);
});

/// Immutable UI-facing view of the sync feature.
class SyncUiState {
  const SyncUiState({
    this.unlocked = false,
    this.syncing = false,
    this.paused = false,
    this.progress,
    this.lastSyncAt,
    this.lastReport,
    this.lastRunSummary,
    this.lastError,
  });

  /// Whether the vault passphrase is currently held in memory.
  final bool unlocked;

  /// A sync run is in flight.
  final bool syncing;

  /// The app was backgrounded mid-sync. The run may still complete in the
  /// background; the UI should say it resumes when the user is back.
  final bool paused;

  /// Live phase counts of the in-flight run, null when not syncing.
  final SyncProgress? progress;

  /// Last successful sync completion time (persisted across restarts).
  final DateTime? lastSyncAt;

  /// Report of the most recent run this session.
  final SyncReport? lastReport;

  /// Persisted summary of the last run (including background runs that
  /// finished while the app was closed).
  final SyncRunSummary? lastRunSummary;

  /// Last unlock/sync failure to surface in the UI.
  final String? lastError;

  SyncUiState copyWith({
    bool? unlocked,
    bool? syncing,
    bool? paused,
    SyncProgress? Function()? progress,
    DateTime? lastSyncAt,
    SyncReport? lastReport,
    SyncRunSummary? Function()? lastRunSummary,
    String? Function()? lastError,
  }) {
    return SyncUiState(
      unlocked: unlocked ?? this.unlocked,
      syncing: syncing ?? this.syncing,
      paused: paused ?? this.paused,
      progress: progress == null ? this.progress : progress(),
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastReport: lastReport ?? this.lastReport,
      lastRunSummary: lastRunSummary == null
          ? this.lastRunSummary
          : lastRunSummary(),
      lastError: lastError == null ? this.lastError : lastError(),
    );
  }
}

/// Owns the in-memory vault key and runs unlock/lock/sync on demand.
///
/// A fresh [SyncEngine] is built per operation from the current settings;
/// the unlocked [VaultCrypto] is carried across instances so changing
/// connection settings never locks the vault mid-session.
class SyncController extends Notifier<SyncUiState> {
  VaultCrypto? _crypto;

  /// Set when the app is backgrounded mid-sync; consumed by the resume
  /// handler to decide whether an automatic restart is needed.
  bool _interrupted = false;

  AppLifecycleListener? _lifecycle;

  @override
  SyncUiState build() {
    unawaited(_hydrateLastSyncAt());
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onPause: handleAppPause,
      onResume: handleAppResume,
    );
    ref.onDispose(() => _lifecycle?.dispose());
    return const SyncUiState();
  }

  Future<void> _hydrateLastSyncAt() async {
    try {
      final repo = ref.read(syncSettingsRepositoryProvider);
      final at = await repo.lastSyncAt();
      final summary = await repo.lastRunSummary();
      state = state.copyWith(lastSyncAt: at, lastRunSummary: () => summary);
    } catch (error) {
      debugPrint('Oneiro: could not load last sync time: $error');
    }
  }

  /// App moved to the background (screen off, app switch). When a sync is
  /// in flight, mark it interrupted and — with a remembered passphrase —
  /// hand the job to WorkManager, which holds a system wake lock and can
  /// finish even if this process is frozen or killed.
  @visibleForTesting
  void handleAppPause() {
    if (!state.syncing) return;
    _interrupted = true;
    state = state.copyWith(paused: true);
    unawaited(() async {
      try {
        final settings = await ref.read(syncConnectionSettingsProvider.future);
        if (settings.isConfigured && settings.rememberPassphrase) {
          await ref.read(backgroundSyncSchedulerProvider).runOnce();
        }
      } catch (error) {
        debugPrint('Oneiro: could not hand sync to background: $error');
      }
    }());
  }

  /// App returned to the foreground. If the interrupted run did not finish
  /// on its own (process frozen mid-flight), restart it — the merge is
  /// idempotent, so re-running is always safe.
  @visibleForTesting
  void handleAppResume() {
    if (state.paused) state = state.copyWith(paused: false);
    if (!_interrupted) return;
    _interrupted = false;
    if (!state.syncing) {
      unawaited(syncNow());
    }
  }

  Future<SyncEngine?> _newEngine() async {
    final store = await ref.read(remoteVaultStoreProvider.future);
    if (store == null) return null;
    return SyncEngine(
      db: ref.read(oneiroDatabaseProvider),
      store: store,
      crypto: _crypto,
    );
  }

  /// Unlocks (creating the vault on first use). Returns null on success or a
  /// user-presentable error message.
  Future<String?> unlock(String passphrase) async {
    final engine = await _newEngine();
    if (engine == null) {
      const message = 'Configure a sync location first';
      state = state.copyWith(lastError: () => message);
      return message;
    }
    try {
      await engine.unlockOrCreateVault(passphrase);
      _crypto = engine.crypto;
      state = state.copyWith(unlocked: true, lastError: () => null);
      // With "remember on this device" the passphrase is available to the
      // WorkManager background isolate too, so periodic sync can run even
      // while the app is closed. Without it, background sync stays off.
      final settings = await ref.read(syncConnectionSettingsProvider.future);
      final scheduler = ref.read(backgroundSyncSchedulerProvider);
      if (settings.rememberPassphrase) {
        unawaited(scheduler.ensureScheduled());
      } else {
        unawaited(scheduler.cancel());
      }
      return null;
    } on WrongPassphraseException {
      const message = 'Passphrase does not match this vault';
      state = state.copyWith(lastError: () => message);
      return message;
    } catch (error) {
      final message = 'Could not unlock the vault: $error';
      state = state.copyWith(lastError: () => message);
      return message;
    }
  }

  /// Locks the vault: drops the in-memory key and any remembered passphrase.
  Future<void> lock() async {
    _crypto = null;
    state = state.copyWith(unlocked: false);
    unawaited(ref.read(backgroundSyncSchedulerProvider).cancel());
    try {
      await ref
          .read(secureCredentialsStoreProvider)
          .delete(SecureCredentialKeys.vaultPassphrase);
    } catch (error) {
      debugPrint('Oneiro: could not clear remembered passphrase: $error');
    }
  }

  /// Runs one sync now. Returns the report, or null when sync is not
  /// configured. Holds a wake lock for the whole run so the phone cannot
  /// doze off mid-upload.
  Future<SyncReport?> syncNow() async {
    final engine = await _newEngine();
    if (engine == null) {
      state = state.copyWith(
        lastError: () => 'Configure a sync location first',
      );
      return null;
    }
    state = state.copyWith(
      syncing: true,
      paused: false,
      progress: () => null,
      lastError: () => null,
    );
    final wakeLock = ref.read(syncWakeLockProvider);
    await wakeLock.acquire();
    try {
      final report = await engine.sync(
        onProgress: (progress) =>
            state = state.copyWith(progress: () => progress),
      );
      _crypto = engine.crypto;
      var lastSyncAt = state.lastSyncAt;
      var lastRunSummary = state.lastRunSummary;
      if (!report.needsUnlock) {
        lastSyncAt = report.syncedAt;
        if (lastSyncAt != null) {
          lastRunSummary = SyncRunSummary(
            pushed: report.pushed,
            pulled: report.pulled,
            deletions: report.deletionsPulled + report.deletionsPushed,
            conflictsResolved: report.conflictsResolved,
            warningCount: report.warnings.length,
            background: false,
            finishedAt: lastSyncAt,
          );
          final repo = ref.read(syncSettingsRepositoryProvider);
          await repo.recordSyncAt(lastSyncAt);
          await repo.recordRunSummary(lastRunSummary);
        }
      }
      state = state.copyWith(
        syncing: false,
        paused: false,
        progress: () => null,
        lastSyncAt: lastSyncAt,
        lastReport: report,
        lastRunSummary: () => lastRunSummary,
      );
      return report;
    } catch (error) {
      state = state.copyWith(
        syncing: false,
        progress: () => null,
        lastError: () => 'Sync failed: $error',
      );
      return null;
    } finally {
      await wakeLock.release();
    }
  }

  /// App-start auto-sync: when sync is configured and the passphrase is
  /// available (in memory or remembered in the credential vault), unlock and
  /// sync once. Every failure is swallowed — auto-sync must never crash
  /// startup; the user can always sync manually from Settings.
  Future<void> tryAutoSyncOnStart() async {
    try {
      final settings = await ref.read(syncConnectionSettingsProvider.future);
      if (!settings.isConfigured) return;
      if (_crypto == null) {
        final remembered = await ref
            .read(secureCredentialsStoreProvider)
            .read(SecureCredentialKeys.vaultPassphrase);
        if (remembered == null || remembered.isEmpty) return;
        final error = await unlock(remembered);
        if (error != null) return;
      }
      await syncNow();
    } catch (error) {
      debugPrint('Oneiro: auto-sync skipped: $error');
    }
  }
}

/// The single sync controller instance.
final syncControllerProvider = NotifierProvider<SyncController, SyncUiState>(
  SyncController.new,
);

/// Side-effect provider: watched once by the app widget, it attempts an
/// app-start auto-sync (configured location + available passphrase only).
final autoSyncProvider = Provider<void>((ref) {
  unawaited(ref.read(syncControllerProvider.notifier).tryAutoSyncOnStart());
});
