import 'package:oneiro/src/features/sync/data/secure_credentials_store.dart';

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
