import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/sync/domain/crypto/vault_crypto.dart';

void main() {
  final fixedSalt = Uint8List.fromList(List.generate(16, (i) => i + 1));

  /// Parses the raw envelope back into its JSON fields.
  Map<String, Object?> parseEnvelope(Uint8List envelope) =>
      jsonDecode(utf8.decode(envelope)) as Map<String, Object?>;

  group('VaultCrypto', () {
    test('create produces a spec-shaped descriptor and unlocks itself',
        () async {
      final (descriptor, crypto) = await VaultCrypto.create(
        'correct horse battery staple',
        salt: fixedSalt,
        kdfN: 1024,
      );

      final json = descriptor.toJson();
      expect(json['format'], 'ovault');
      expect(json['v'], 1);
      final kdf = json['kdf']! as Map<String, Object?>;
      expect(kdf['algo'], 'scrypt');
      expect(kdf['N'], 1024);
      expect(kdf['r'], 8);
      expect(kdf['p'], 1);
      // OVault v1 pins production-strength scrypt parameters as defaults.
      expect(VaultCrypto.defaultKdfN, 32768);
      expect(VaultCrypto.defaultKdfR, 8);
      expect(VaultCrypto.defaultKdfP, 1);
      expect(base64Decode(kdf['salt']! as String), fixedSalt);
      expect(base64Decode(json['check']! as String), isNotEmpty);

      // The same passphrase unlocks a vault described by this descriptor.
      final unlocked = await VaultCrypto.unlock(
        'correct horse battery staple',
        descriptor,
      );
      final envelope = await unlocked.encryptJson({'probe': 1});
      expect(await crypto.decryptJson(envelope), {'probe': 1});
    });

    test('JSON round-trip preserves the payload exactly', () async {
      final (_, crypto) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      const payload = {
        'id': 'entry-1',
        'dreamDate': 1778457600000,
        'body': 'Flying over an ocean of stars\nwith #lucidity',
        'isLucid': true,
        'createdAt': 1000,
        'updatedAt': 2000,
        'deletedAt': null,
      };
      final envelope = await crypto.encryptJson(payload);
      expect(await crypto.decryptJson(envelope), payload);
    });

    test('a wrong passphrase fails with WrongPassphraseException', () async {
      final (descriptor, _) = await VaultCrypto.create(
        'right',
        salt: fixedSalt,
        kdfN: 256,
      );
      await expectLater(
        VaultCrypto.unlock('wrong', descriptor),
        throwsA(isA<WrongPassphraseException>()),
      );
    });

    test('every encryption uses a fresh nonce', () async {
      final (_, crypto) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      const payload = {'same': 'plaintext'};
      final first = parseEnvelope(await crypto.encryptJson(payload));
      final second = parseEnvelope(await crypto.encryptJson(payload));
      expect(first['nonce'], isNot(second['nonce']));
      expect(first['ct'], isNot(second['ct']));
    });

    test('tampering with the ciphertext fails authentication', () async {
      final (_, crypto) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      final envelope = parseEnvelope(
        await crypto.encryptJson({'secret': 'value'}),
      );
      final ct = base64Decode(envelope['ct']! as String);
      ct[3] ^= 0xFF; // flip one ciphertext byte
      final tampered = Uint8List.fromList(
        utf8.encode(
          jsonEncode({...envelope, 'ct': base64Encode(ct)}),
        ),
      );
      await expectLater(
        crypto.decryptJson(tampered),
        throwsA(isA<VaultAuthenticationException>()),
      );
    });

    test('tampering with the nonce fails authentication', () async {
      final (_, crypto) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      final envelope = parseEnvelope(
        await crypto.encryptJson({'secret': 'value'}),
      );
      final nonce = base64Decode(envelope['nonce']! as String);
      nonce[0] ^= 0x01;
      final tampered = Uint8List.fromList(
        utf8.encode(
          jsonEncode({...envelope, 'nonce': base64Encode(nonce)}),
        ),
      );
      await expectLater(
        crypto.decryptJson(tampered),
        throwsA(isA<VaultAuthenticationException>()),
      );
    });

    test('descriptor serialization round-trips through JSON', () async {
      final (descriptor, _) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      final restored = VaultDescriptor.decode(descriptor.encode());
      expect(restored.toJson(), descriptor.toJson());
    });

    test('malformed descriptors and envelopes throw FormatException', () {
      expect(
        () => VaultDescriptor.decode('{"format":"other","v":1}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VaultDescriptor.decode('not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => VaultDescriptor.decode('{"format":"ovault","v":99}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed envelopes throw FormatException', () async {
      final (_, crypto) = await VaultCrypto.create('pw', salt: fixedSalt, kdfN: 256);
      await expectLater(
        crypto.decryptJson(Uint8List.fromList(utf8.encode('not json'))),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        crypto.decryptJson(
          Uint8List.fromList(utf8.encode('{"v":2,"nonce":"eA==","ct":"eA=="}')),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
