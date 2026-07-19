import 'package:oneiro/src/features/sync/background/background_sync.dart';
import 'package:oneiro/src/features/sync/data/secure_credentials_store.dart';
import 'package:oneiro/src/features/sync/data/sync_wake_lock.dart';

/// In-memory [SecureCredentialsStore] for widget/unit tests — mirrors the
/// fake-plugin pattern used by the backup and training features.
class InMemorySecureCredentialsStore implements SecureCredentialsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Records acquire/release calls instead of touching the screen wake lock.
class FakeSyncWakeLock implements SyncWakeLock {
  int acquireCount = 0;
  int releaseCount = 0;

  @override
  Future<void> acquire() async {
    acquireCount++;
  }

  @override
  Future<void> release() async {
    releaseCount++;
  }
}

/// Records background-sync scheduling calls; no WorkManager involvement.
class FakeBackgroundSyncScheduler implements BackgroundSyncScheduler {
  int ensureScheduledCount = 0;
  int cancelCount = 0;

  @override
  Future<void> ensureScheduled() async {
    ensureScheduledCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}
