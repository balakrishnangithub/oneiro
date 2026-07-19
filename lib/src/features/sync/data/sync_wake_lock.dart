import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device awake for the duration of a sync run.
///
/// Without this, a long first sync (hundreds of entries over WebDAV) loses
/// the network the moment the screen times out and Android suspends the app —
/// the run then ends half-uploaded with a pile of per-file warnings. The
/// wake lock is held only while [SyncEngine.sync] runs and always released
/// afterwards (success or failure).
///
/// Behind an interface so tests can record acquire/release without touching
/// the platform channel.
abstract class SyncWakeLock {
  Future<void> acquire();
  Future<void> release();
}

/// [SyncWakeLock] backed by `wakelock_plus`. Failures are swallowed on
/// purpose: a sync must never fail because the wake lock was unavailable
/// (emulators, desktops, odd ROMs).
class WakelockPlusSyncWakeLock implements SyncWakeLock {
  @override
  Future<void> acquire() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // Best effort only.
    }
  }

  @override
  Future<void> release() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Best effort only.
    }
  }
}
