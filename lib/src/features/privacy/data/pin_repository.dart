import '../../sync/data/secure_credentials_store.dart';
import '../domain/pin_hasher.dart';

/// Persists the journal-lock PIN behind the platform credential vault.
///
/// Only the scrypt hash string from [PinHasher] is ever stored — never the
/// PIN itself, and never anywhere near drift or `app_settings`. Presence of
/// the stored hash IS the "PIN lock enabled" flag.
class PinRepository {
  PinRepository(this._store);

  /// Secure-storage key for the PIN hash string.
  static const hashKey = 'pin_lock_hash';

  final SecureCredentialsStore _store;

  /// Whether a PIN is set.
  Future<bool> isEnabled() async => await _store.read(hashKey) != null;

  /// The stored PIN length (for the lock pad's dot count), or null when no
  /// PIN is set or the stored value is malformed.
  Future<int?> pinLength() async {
    final stored = await _store.read(hashKey);
    if (stored == null) return null;
    return PinHasher.storedPinLength(stored);
  }

  /// Sets (or replaces) the PIN. Throws [ArgumentError] on an invalid PIN.
  Future<void> setPin(String pin) => _store.write(hashKey, PinHasher.hash(pin));

  /// Returns true when [pin] matches the stored hash. False when no PIN is
  /// set or the stored value is malformed.
  Future<bool> verify(String pin) async {
    final stored = await _store.read(hashKey);
    if (stored == null) return false;
    return PinHasher.verify(pin, stored);
  }

  /// Removes the PIN entirely (disable flow).
  Future<void> clearPin() => _store.delete(hashKey);
}
