import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys under which sync secrets live in the platform credential vault.
///
/// These values must NEVER be written to drift or `app_settings`.
abstract final class SecureCredentialKeys {
  /// The WebDAV account password.
  static const syncPassword = 'sync_password';

  /// The vault passphrase, only present when the user opted into
  /// "remember on this device".
  static const vaultPassphrase = 'vault_passphrase';
}

/// Abstraction over the platform credential vault (Keychain / Keystore /
/// libsecret), so sync secrets stay widget-testable and never touch drift.
abstract class SecureCredentialsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// [SecureCredentialsStore] backed by `flutter_secure_storage`.
class FlutterSecureCredentialsStore implements SecureCredentialsStore {
  FlutterSecureCredentialsStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
