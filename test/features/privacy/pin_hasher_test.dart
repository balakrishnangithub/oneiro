import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/privacy/domain/pin_hasher.dart';

void main() {
  final fixedSalt = Uint8List.fromList(List.generate(16, (i) => 200 - i));

  group('PinHasher.hash', () {
    test('round-trip: a stored hash verifies the same PIN', () {
      final stored = PinHasher.hash('4471', salt: fixedSalt);
      expect(PinHasher.verify('4471', stored), isTrue);
    });

    test('wrong PINs are rejected, including off-by-one digit edits', () {
      final stored = PinHasher.hash('4471', salt: fixedSalt);
      expect(PinHasher.verify('4472', stored), isFalse);
      expect(PinHasher.verify('447', stored), isFalse);
      expect(PinHasher.verify('44710', stored), isFalse);
      expect(PinHasher.verify('', stored), isFalse);
      expect(PinHasher.verify('abcd', stored), isFalse);
    });

    test('salt uniqueness: two hashes of the same PIN differ, both verify',
        () {
      final first = PinHasher.hash('880123');
      final second = PinHasher.hash('880123');
      expect(first, isNot(second));
      // And the salts inside really are different random values.
      expect(first.split('\$')[5], isNot(second.split('\$')[5]));
      expect(PinHasher.verify('880123', first), isTrue);
      expect(PinHasher.verify('880123', second), isTrue);
    });

    test('stored string is self-describing and never contains the PIN', () {
      final stored = PinHasher.hash('4471', salt: fixedSalt);
      final parts = stored.split('\$');
      expect(parts, hasLength(7));
      expect(parts[0], PinHasher.formatTag);
      expect(int.parse(parts[1]), PinHasher.defaultKdfN);
      expect(int.parse(parts[2]), PinHasher.kdfR);
      expect(int.parse(parts[3]), PinHasher.kdfP);
      expect(parts[4], '4');
      expect(base64Decode(parts[5]), fixedSalt);
      expect(base64Decode(parts[6]), hasLength(PinHasher.hashLength));
      expect(stored.contains('4471'), isFalse);
      // Production cost stays pinned at 2^14 as specified.
      expect(PinHasher.defaultKdfN, 16384);
    });

    test('rejects invalid PINs instead of hashing them', () {
      expect(() => PinHasher.hash('123'), throwsArgumentError); // too short
      expect(() => PinHasher.hash('123456789'), throwsArgumentError); // long
      expect(() => PinHasher.hash('12a4'), throwsArgumentError); // non-digit
      expect(() => PinHasher.hash('12 4'), throwsArgumentError);
      // Boundary lengths are fine.
      expect(PinHasher.verify('0000', PinHasher.hash('0000')), isTrue);
      expect(
        PinHasher.verify('12345678', PinHasher.hash('12345678')),
        isTrue,
      );
    });

    test('isValidPin encodes the 4–8 digit rule', () {
      expect(PinHasher.isValidPin('1234'), isTrue);
      expect(PinHasher.isValidPin('12345678'), isTrue);
      expect(PinHasher.isValidPin('123'), isFalse);
      expect(PinHasher.isValidPin('123456789'), isFalse);
      expect(PinHasher.isValidPin('12b4'), isFalse);
    });
  });

  group('PinHasher.verify robustness', () {
    test('malformed stored strings return false instead of throwing', () {
      expect(PinHasher.verify('4471', ''), isFalse);
      expect(PinHasher.verify('4471', 'garbage'), isFalse);
      expect(PinHasher.verify('4471', 'opin1\$1\$2\$3'), isFalse);
      expect(
        PinHasher.verify('4471', 'otherv1\$16384\$8\$1\$4\$AAAA\$AAAA'),
        isFalse,
      );
      // Valid shape but broken base64.
      expect(
        PinHasher.verify('4471', 'opin1\$16384\$8\$1\$4\$!!!\$%%%'),
        isFalse,
      );
      // Tampered hash.
      final stored = PinHasher.hash('4471', salt: fixedSalt);
      final parts = stored.split('\$');
      parts[6] = base64Encode(Uint8List(32)); // all-zero hash
      expect(PinHasher.verify('4471', parts.join('\$')), isFalse);
    });
  });

  group('PinHasher.storedPinLength', () {
    test('reads back the length for the lock pad', () {
      expect(PinHasher.storedPinLength(PinHasher.hash('4471')), 4);
      expect(PinHasher.storedPinLength(PinHasher.hash('12345678')), 8);
    });

    test('null on malformed strings', () {
      expect(PinHasher.storedPinLength(''), isNull);
      expect(PinHasher.storedPinLength('opin1\$16384\$8\$1\$99\$AA\$AA'),
          isNull);
    });
  });
}
