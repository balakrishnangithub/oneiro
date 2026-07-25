import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

/// Hashes and verifies journal-lock PINs.
///
/// A PIN is NEVER stored in plaintext. What persists (in the platform
/// credential vault, never in drift) is a compact self-describing string:
///
/// ```
/// opin1$N$r$p$len$saltB64$hashB64
/// ```
///
/// where `hash = scrypt(PIN, salt, N, r, p)` with a fresh random salt per
/// PIN. The scrypt derivation reuses the pointycastle pattern from
/// `features/sync/domain/crypto/vault_crypto.dart`; the cost is lower than
/// the vault's because the threat model here is a curious bystander, not an
/// offline brute-force of an uploaded vault.
///
/// The PIN length is stored alongside (`len`) — it is not secret (the hash
/// already assumes a short numeric space) and lets the lock pad auto-submit
/// at the right number of digits.
abstract final class PinHasher {
  /// Stored-string format tag, so a future v2 can migrate safely.
  static const formatTag = 'opin1';

  /// scrypt CPU/memory cost parameter (2^14).
  static const defaultKdfN = 16384;

  /// scrypt block-size and parallelization parameters.
  static const kdfR = 8;
  static const kdfP = 1;

  /// Random salt length in bytes.
  static const saltLength = 16;

  /// Derived hash length in bytes.
  static const hashLength = 32;

  /// Allowed PIN lengths (inclusive).
  static const minPinLength = 4;
  static const maxPinLength = 8;

  /// A valid PIN is 4–8 ASCII digits, nothing else.
  static bool isValidPin(String pin) {
    if (pin.length < minPinLength || pin.length > maxPinLength) {
      return false;
    }
    return pin.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);
  }

  static Uint8List _derive(String pin, Uint8List salt, int n) {
    final derivator = Scrypt()
      ..init(ScryptParameters(n, kdfR, kdfP, hashLength, salt));
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Hashes [pin] with a fresh random [salt] (or the supplied one in tests)
  /// and returns the stored-string form. Throws [ArgumentError] on a PIN
  /// outside the 4–8 digit rule.
  static String hash(
    String pin, {
    Uint8List? salt,
    Random? random,
    int kdfN = defaultKdfN,
  }) {
    if (!isValidPin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be 4–8 digits');
    }
    final effectiveSalt =
        salt ?? _randomBytes(saltLength, random ?? Random.secure());
    if (effectiveSalt.length != saltLength) {
      throw ArgumentError.value(
        effectiveSalt,
        'salt',
        'must be $saltLength bytes',
      );
    }
    final digest = _derive(pin, effectiveSalt, kdfN);
    return '$formatTag\$$kdfN\$$kdfR\$$kdfP\$${pin.length}'
        '\$${base64Encode(effectiveSalt)}\$${base64Encode(digest)}';
  }

  /// Verifies [pin] against a stored string from [hash].
  ///
  /// Returns false (never throws) for malformed stored strings, unknown
  /// formats, and plain wrong PINs.
  static bool verify(String pin, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 7 || parts[0] != formatTag) return false;
    final n = int.tryParse(parts[1]);
    final r = int.tryParse(parts[2]);
    final p = int.tryParse(parts[3]);
    if (n == null || r != kdfR || p != kdfP) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(parts[5]);
      expected = base64Decode(parts[6]);
    } on FormatException {
      return false;
    }
    if (salt.length != saltLength || expected.length != hashLength) {
      return false;
    }
    final candidate = _derive(pin, salt, n);
    return _constantTimeEquals(candidate, expected);
  }

  /// Async variant of [hash]: the scrypt derivation runs inside
  /// [Isolate.run] so the UI isolate never stalls on a PIN submit.
  ///
  /// Validation and salt generation stay on the caller isolate (identical
  /// semantics to [hash], including the [ArgumentError]s); only the
  /// CPU-heavy [_derive] crosses the isolate boundary. String, [Uint8List]
  /// and int are all sendable, so the closure captures nothing the isolate
  /// cannot receive.
  static Future<String> hashAsync(
    String pin, {
    Uint8List? salt,
    Random? random,
    int kdfN = defaultKdfN,
  }) async {
    if (!isValidPin(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be 4–8 digits');
    }
    final effectiveSalt =
        salt ?? _randomBytes(saltLength, random ?? Random.secure());
    if (effectiveSalt.length != saltLength) {
      throw ArgumentError.value(
        effectiveSalt,
        'salt',
        'must be $saltLength bytes',
      );
    }
    final digest = await Isolate.run(() => _derive(pin, effectiveSalt, kdfN));
    return '$formatTag\$$kdfN\$$kdfR\$$kdfP\$${pin.length}'
        '\$${base64Encode(effectiveSalt)}\$${base64Encode(digest)}';
  }

  /// Async variant of [verify]: malformed stored strings are rejected on the
  /// caller isolate (identical false-semantics to [verify]); the scrypt
  /// derivation and the constant-time comparison run inside [Isolate.run] so
  /// a wrong-digit tap never freezes the lock pad.
  static Future<bool> verifyAsync(String pin, String stored) async {
    final parts = stored.split('\$');
    if (parts.length != 7 || parts[0] != formatTag) return false;
    final n = int.tryParse(parts[1]);
    final r = int.tryParse(parts[2]);
    final p = int.tryParse(parts[3]);
    if (n == null || r != kdfR || p != kdfP) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(parts[5]);
      expected = base64Decode(parts[6]);
    } on FormatException {
      return false;
    }
    if (salt.length != saltLength || expected.length != hashLength) {
      return false;
    }
    final candidate = await Isolate.run(() => _derive(pin, salt, n));
    return _constantTimeEquals(candidate, expected);
  }

  /// The PIN length recorded in a stored string, or null when malformed.
  ///
  /// Not secret: used only so the lock pad knows how many dots to draw.
  static int? storedPinLength(String stored) {
    final parts = stored.split('\$');
    if (parts.length != 7 || parts[0] != formatTag) return null;
    final length = int.tryParse(parts[4]);
    if (length == null || length < minPinLength || length > maxPinLength) {
      return null;
    }
    return length;
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length, Random random) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
