import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/sync/domain/crypto/vault_archive.dart';
import 'package:oneiro/src/features/sync/domain/synced_entry.dart';

void main() {
  SyncedEntry entry(
    String id, {
    int updatedAt = 1000,
    int? deletedAt,
    bool isLucid = false,
  }) => SyncedEntry(
    id: id,
    dreamDate: 1778457600000,
    body: 'body of $id',
    isLucid: isLucid,
    createdAt: 900,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );

  test('round-trip preserves entries, tombstones included', () {
    final entries = [
      entry('b-entry', isLucid: true),
      entry('a-entry', updatedAt: 2000),
      entry('z-gone', updatedAt: 3000, deletedAt: 3000),
    ];

    final decoded = VaultArchive.decode(VaultArchive.encode(entries));

    // Sorted by id, content identical.
    expect(decoded.map((e) => e.id), ['a-entry', 'b-entry', 'z-gone']);
    expect(decoded[1], entry('b-entry', isLucid: true));
    expect(decoded[2].deletedAt, 3000);
  });

  test('encoding is deterministic regardless of input order', () {
    final a = VaultArchive.encode([entry('x'), entry('y')]);
    final b = VaultArchive.encode([entry('y'), entry('x')]);
    expect(a, b);
  });

  test('compression actually compresses repetitive text', () {
    final big = [
      for (var i = 0; i < 50; i++)
        SyncedEntry(
          id: 'entry-$i',
          dreamDate: 1778457600000,
          body: 'the same recurring dream again and again ' * 10,
          isLucid: false,
          createdAt: 900,
          updatedAt: 1000,
          deletedAt: null,
        ),
    ];
    final encoded = VaultArchive.encode(big);
    final jsonSize = utf8
        .encode(jsonEncode([for (final e in big) e.toJson()]))
        .length;
    expect(encoded.length, lessThan(jsonSize ~/ 2));
  });

  test('decode rejects garbage, wrong versions and broken schemas', () {
    expect(
      () => VaultArchive.decode(Uint8List.fromList('not gzip'.codeUnits)),
      throwsA(isA<FormatException>()),
    );

    Uint8List gzipOf(String json) =>
        Uint8List.fromList(GZipEncoder().encode(utf8.encode(json)));

    expect(
      () => VaultArchive.decode(gzipOf('{"v":1,"entries":[]}')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => VaultArchive.decode(gzipOf('{"v":2}')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => VaultArchive.decode(gzipOf('{"v":2,"entries":[{"id":42}]}')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => VaultArchive.decode(gzipOf('not json')),
      throwsA(isA<FormatException>()),
    );
  });
}
