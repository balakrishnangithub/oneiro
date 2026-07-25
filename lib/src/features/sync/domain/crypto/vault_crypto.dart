import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/scrypt.dart';

/// AEAD authentication of an encrypted OVault blob failed.
///
/// Raised when a ciphertext (or its nonce) was tampered with or truncated,
/// so the GCM tag does not verify.
class VaultAuthenticationException implements Exception {
  const VaultAuthenticationException([
    this.message = 'encrypted payload failed authentication',
  ]);

  final String message;

  @override
  String toString() => 'VaultAuthenticationException: $message';
}

/// The passphrase does not match the vault's key-check block.
class WrongPassphraseException extends VaultAuthenticationException {
  const WrongPassphraseException([
    super.message = 'passphrase does not match this vault',
  ]);

  @override
  String toString() => 'WrongPassphraseException: $message';
}

/// The unencrypted vault descriptor stored as `vault.json`.
///
/// Contains the KDF parameters and salt plus the key-check block — never any
/// key material — so it is safe to store in plaintext on the server.
class VaultDescriptor {
  const VaultDescriptor({
    required this.kdfN,
    required this.kdfR,
    required this.kdfP,
    required this.salt,
    required this.check,
  });

  /// scrypt CPU/memory cost parameter (a power of two).
  final int kdfN;

  /// scrypt block-size parameter.
  final int kdfR;

  /// scrypt parallelization parameter.
  final int kdfP;

  /// Random KDF salt, [VaultCrypto.saltLength] bytes.
  final Uint8List salt;

  /// AES-GCM(key, zero nonce, [VaultCrypto.keyCheckPlaintext]) — ciphertext
  /// concatenated with its 16-byte tag. Proves knowledge of the master key.
  final Uint8List check;

  static const format = 'ovault';
  static const version = 2;
  static const kdfAlgorithm = 'scrypt';

  Map<String, Object?> toJson() => {
    'format': format,
    'v': version,
    'kdf': {
      'algo': kdfAlgorithm,
      'N': kdfN,
      'r': kdfR,
      'p': kdfP,
      'salt': base64Encode(salt),
    },
    'check': base64Encode(check),
  };

  /// Canonical (fixed key order) JSON encoding stored in `vault.json`.
  String encode() => jsonEncode(toJson());

  factory VaultDescriptor.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('not an OVault descriptor');
    }
    if (json['v'] != version) {
      throw FormatException('unsupported OVault version: ${json['v']}');
    }
    final kdf = json['kdf'];
    if (kdf is! Map || kdf['algo'] != kdfAlgorithm) {
      throw const FormatException('unsupported or missing KDF parameters');
    }
    Uint8List decodeField(Object? value, String name) {
      if (value is! String) {
        throw FormatException('descriptor field "$name" is missing');
      }
      try {
        return base64Decode(value);
      } on FormatException {
        throw FormatException('descriptor field "$name" is not valid base64');
      }
    }

    int intField(Object? value, String name) {
      if (value is! int) {
        throw FormatException('descriptor field "$name" is missing');
      }
      return value;
    }

    return VaultDescriptor(
      kdfN: intField(kdf['N'], 'kdf.N'),
      kdfR: intField(kdf['r'], 'kdf.r'),
      kdfP: intField(kdf['p'], 'kdf.p'),
      salt: decodeField(kdf['salt'], 'kdf.salt'),
      check: decodeField(json['check'], 'check'),
    );
  }

  factory VaultDescriptor.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('vault descriptor is not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('vault descriptor is not a JSON object');
    }
    return VaultDescriptor.fromJson(decoded);
  }
}

/// OVault v2 crypto core: passphrase → master key → AES-256-GCM envelopes.
///
/// Everything is encrypted client-side before upload; the server only ever
/// stores opaque envelopes. The master key lives only in this instance's
/// memory. See `docs/sync-format.md` for the full format specification.
///
/// v2 encrypts a single gzip-compressed archive instead of per-entry files;
/// the envelope format itself is unchanged (only the version field moved to
/// 2, so v1 clients fail loudly instead of misreading an archive).
class VaultCrypto {
  VaultCrypto._(this._masterKey);

  final Uint8List _masterKey;

  /// A copy of the in-memory master key.
  ///
  /// Exists so [VaultCrypto.encryptEnvelopeRaw]/[VaultCrypto.decryptEnvelopeRaw]
  /// (and the `VaultArchive` off-isolate helpers built on them) can run the
  /// heavy AES-GCM + gzip work on a background isolate within the SAME
  /// process. The bytes must never leave this process — no persistence, no
  /// platform channels, no logs.
  Uint8List get masterKeyBytes => Uint8List.fromList(_masterKey);

  // --- OVault v2 constants ---------------------------------------------------

  /// scrypt parameters pinned by the OVault format.
  static const defaultKdfN = 32768; // 2^15
  static const defaultKdfR = 8;
  static const defaultKdfP = 1;

  /// Random KDF salt length in bytes.
  static const saltLength = 16;

  /// Derived master-key length in bytes (AES-256).
  static const keyLength = 32;

  /// Fresh GCM nonce length in bytes, one per encryption.
  static const nonceLength = 12;

  /// GCM authentication tag length in bytes (appended to the ciphertext).
  static const tagLength = 16;

  /// Fixed plaintext of the key-check block.
  static const keyCheckPlaintext = 'ovault-key-check';

  /// Fixed nonce of the key-check block (safe: it encrypts exactly one,
  /// public, constant message under each vault's unique key).
  static final _keyCheckNonce = Uint8List(nonceLength);

  // --- Key derivation --------------------------------------------------------

  static Uint8List _deriveKey(
    String passphrase,
    Uint8List salt, {
    required int n,
    required int r,
    required int p,
  }) {
    final derivator = Scrypt()
      ..init(ScryptParameters(n, r, p, keyLength, salt));
    return derivator.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Runs [_deriveKey] on a background isolate.
  ///
  /// scrypt at production cost (N = 2^15) takes well over a second on a
  /// phone; running it on the UI isolate froze the whole app (most visibly
  /// the PIN pad) during every cold-start auto-unlock. All captured values
  /// are sendable (String, [Uint8List], ints), so [Isolate.run] can carry
  /// the closure across.
  static Future<Uint8List> _deriveKeyOffIsolate(
    String passphrase,
    Uint8List salt, {
    required int n,
    required int r,
    required int p,
  }) {
    return Isolate.run(() => _deriveKey(passphrase, salt, n: n, r: r, p: p));
  }

  /// Creates a new vault: generates a random [salt] (unless supplied, e.g. by
  /// tests), derives the master key and returns the descriptor to upload plus
  /// the unlocked crypto instance.
  static Future<(VaultDescriptor, VaultCrypto)> create(
    String passphrase, {
    Uint8List? salt,
    Random? random,
    int kdfN = defaultKdfN,
    int kdfR = defaultKdfR,
    int kdfP = defaultKdfP,
  }) async {
    final effectiveSalt =
        salt ?? _randomBytes(saltLength, random ?? Random.secure());
    if (effectiveSalt.length != saltLength) {
      throw ArgumentError.value(
        effectiveSalt.length,
        'salt',
        'must be $saltLength bytes',
      );
    }
    final key = await _deriveKeyOffIsolate(
      passphrase,
      effectiveSalt,
      n: kdfN,
      r: kdfR,
      p: kdfP,
    );
    final crypto = VaultCrypto._(key);
    final check = await crypto._encryptRaw(
      utf8.encode(keyCheckPlaintext),
      _keyCheckNonce,
    );
    return (
      VaultDescriptor(
        kdfN: kdfN,
        kdfR: kdfR,
        kdfP: kdfP,
        salt: effectiveSalt,
        check: check,
      ),
      crypto,
    );
  }

  /// Unlocks an existing vault from its [descriptor].
  ///
  /// Throws [WrongPassphraseException] when the derived key fails to
  /// authenticate the key-check block, and [FormatException] when the
  /// descriptor itself is malformed.
  static Future<VaultCrypto> unlock(
    String passphrase,
    VaultDescriptor descriptor,
  ) async {
    final key = await _deriveKeyOffIsolate(
      passphrase,
      descriptor.salt,
      n: descriptor.kdfN,
      r: descriptor.kdfR,
      p: descriptor.kdfP,
    );
    final crypto = VaultCrypto._(key);
    try {
      final plaintext = await crypto._decryptRaw(
        descriptor.check,
        _keyCheckNonce,
      );
      if (utf8.decode(plaintext) != keyCheckPlaintext) {
        throw const WrongPassphraseException();
      }
    } on VaultAuthenticationException {
      throw const WrongPassphraseException();
    }
    return crypto;
  }

  // --- Envelope encryption ---------------------------------------------------

  /// Encrypts arbitrary plaintext bytes into an OVault envelope
  /// (`{"v":2,"nonce":b64,"ct":b64}`), UTF-8 encoded. A fresh random nonce is
  /// generated for every call.
  Future<Uint8List> encryptBytes(Uint8List plaintext, {Random? random}) {
    return encryptEnvelopeRaw(
      _masterKey,
      plaintext,
      randomNonce(random: random),
    );
  }

  /// Decrypts an OVault envelope back into raw plaintext bytes.
  ///
  /// Throws [FormatException] on malformed envelopes and
  /// [VaultAuthenticationException] when the authentication tag does not
  /// verify (tampered or wrong key).
  Future<Uint8List> decryptBytes(Uint8List envelopeBytes) {
    return decryptEnvelopeRaw(_masterKey, envelopeBytes);
  }

  /// A fresh random GCM nonce ([nonceLength] bytes).
  ///
  /// Exposed so off-isolate encryption paths ([encryptEnvelopeRaw]) can draw
  /// the nonce on the caller side (keeping [Random.secure] usage testable)
  /// while the sealing itself runs in a background isolate.
  static Uint8List randomNonce({Random? random}) =>
      _randomBytes(nonceLength, random ?? Random.secure());

  /// Static twin of [encryptBytes] with a caller-provided [nonce], usable
  /// inside a background isolate: it recreates the cipher locally and never
  /// touches instance state.
  ///
  /// Same envelope layout and semantics as [encryptBytes]; the nonce comes
  /// from the caller because GCM nonce reuse under one key is fatal, and the
  /// isolate boundary must never silently duplicate a "random" draw.
  static Future<Uint8List> encryptEnvelopeRaw(
    Uint8List masterKey,
    Uint8List plaintext,
    Uint8List nonce,
  ) async {
    final ct = await _encryptRawWith(masterKey, plaintext, nonce);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'v': VaultDescriptor.version,
          'nonce': base64Encode(nonce),
          'ct': base64Encode(ct),
        }),
      ),
    );
  }

  /// Static twin of [decryptBytes], usable inside a background isolate:
  /// recreates the cipher locally and never touches instance state.
  ///
  /// Throws [FormatException] on malformed envelopes and
  /// [VaultAuthenticationException] when the authentication tag does not
  /// verify (tampered or wrong key).
  static Future<Uint8List> decryptEnvelopeRaw(
    Uint8List masterKey,
    Uint8List envelopeBytes,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(envelopeBytes));
    } on FormatException {
      throw const FormatException('envelope is not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('envelope is not a JSON object');
    }
    if (decoded['v'] != VaultDescriptor.version) {
      throw FormatException('unsupported envelope version: ${decoded['v']}');
    }
    final nonceB64 = decoded['nonce'];
    final ctB64 = decoded['ct'];
    if (nonceB64 is! String || ctB64 is! String) {
      throw const FormatException('envelope misses nonce or ct');
    }
    final Uint8List nonce;
    final Uint8List ct;
    try {
      nonce = base64Decode(nonceB64);
      ct = base64Decode(ctB64);
    } on FormatException {
      throw const FormatException('envelope fields are not valid base64');
    }
    if (nonce.length != nonceLength) {
      throw FormatException('nonce must be $nonceLength bytes');
    }
    return _decryptRawWith(masterKey, ct, nonce);
  }

  /// Encrypts a canonical JSON payload into an OVault envelope. A fresh
  /// random nonce is generated for every call.
  Future<Uint8List> encryptJson(Map<String, Object?> value, {Random? random}) {
    return encryptBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(value))),
      random: random,
    );
  }

  /// Decrypts an OVault envelope back into its JSON payload.
  ///
  /// Throws [FormatException] on malformed envelopes and
  /// [VaultAuthenticationException] when the authentication tag does not
  /// verify (tampered or wrong key).
  Future<Map<String, Object?>> decryptJson(Uint8List envelopeBytes) async {
    final plaintext = await decryptBytes(envelopeBytes);
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(plaintext));
    } on FormatException {
      throw const FormatException('decrypted payload is not valid JSON');
    }
    if (payload is! Map<String, Object?>) {
      throw const FormatException('decrypted payload is not a JSON object');
    }
    return payload;
  }

  // --- Raw GCM helpers -------------------------------------------------------

  /// Returns ciphertext with the 16-byte tag appended.
  Future<Uint8List> _encryptRaw(List<int> plaintext, Uint8List nonce) =>
      _encryptRawWith(_masterKey, plaintext, nonce);

  /// Expects ciphertext with the 16-byte tag appended.
  Future<Uint8List> _decryptRaw(Uint8List ct, Uint8List nonce) =>
      _decryptRawWith(_masterKey, ct, nonce);

  /// Static variant of [_encryptRaw]: the cipher is created locally so the
  /// helper is safe to call inside a background isolate (no instance state,
  /// no shared `AesGcm`).
  static Future<Uint8List> _encryptRawWith(
    Uint8List masterKey,
    List<int> plaintext,
    Uint8List nonce,
  ) async {
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: SecretKey(masterKey),
      nonce: nonce,
    );
    final out = Uint8List(box.cipherText.length + tagLength);
    out.setRange(0, box.cipherText.length, box.cipherText);
    out.setRange(box.cipherText.length, out.length, box.mac.bytes);
    return out;
  }

  /// Static variant of [_decryptRaw]; see [_encryptRawWith] for why the
  /// cipher is created locally.
  static Future<Uint8List> _decryptRawWith(
    Uint8List masterKey,
    Uint8List ct,
    Uint8List nonce,
  ) async {
    if (ct.length < tagLength) {
      throw const FormatException('ciphertext shorter than the GCM tag');
    }
    try {
      final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          ct.sublist(0, ct.length - tagLength),
          nonce: nonce,
          mac: Mac(ct.sublist(ct.length - tagLength)),
        ),
        secretKey: SecretKey(masterKey),
      );
      return Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const VaultAuthenticationException();
    }
  }

  static Uint8List _randomBytes(int length, Random random) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
