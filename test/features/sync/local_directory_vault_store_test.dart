import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/sync/data/local_directory_vault_store.dart';
import 'package:oneiro/src/features/sync/data/webdav_vault_store.dart';

void main() {
  late Directory tempDir;
  late LocalDirectoryVaultStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('oneiro_vault_store_test');
    store = LocalDirectoryVaultStore(tempDir.path);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('ensureStructure creates the vault layout and is idempotent', () async {
    await store.ensureStructure();
    expect(Directory('${tempDir.path}/entries').existsSync(), isTrue);
    await store.ensureStructure(); // second call is a no-op
    expect(Directory('${tempDir.path}/entries').existsSync(), isTrue);
  });

  test('descriptor round-trips; absent descriptor reads as null', () async {
    expect(await store.readDescriptor(), isNull);
    await store.writeDescriptor('{"format":"ovault"}');
    expect(await store.readDescriptor(), '{"format":"ovault"}');
  });

  test('write, list, read and delete entry files', () async {
    expect(await store.listEntryIds(), isEmpty);
    expect(await store.read('missing'), isNull);

    await store.write('b-entry', Uint8List.fromList([2]));
    await store.write('a-entry', Uint8List.fromList([1, 2, 3]));

    expect(await store.listEntryIds(), ['a-entry', 'b-entry']);
    expect(await store.read('a-entry'), [1, 2, 3]);

    await store.delete('a-entry');
    expect(await store.listEntryIds(), ['b-entry']);
    expect(await store.read('a-entry'), isNull);

    // Deleting twice is fine.
    await store.delete('a-entry');
  });

  test('list ignores non-json files and subfolders', () async {
    await store.ensureStructure();
    await File('${tempDir.path}/entries/notes.txt').writeAsString('x');
    await Directory('${tempDir.path}/entries/nested').create();
    await store.write('real-entry', Uint8List.fromList([9]));
    expect(await store.listEntryIds(), ['real-entry']);
  });

  test('rejects path-traversal ids', () async {
    await expectLater(
      store.write('../evil', Uint8List.fromList([1])),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('normalizeVaultBasePath enforces leading slash, strips trailing', () {
    expect(normalizeVaultBasePath(''), defaultVaultBasePath);
    expect(normalizeVaultBasePath('vault'), '/vault');
    expect(normalizeVaultBasePath('/vault/'), '/vault');
    expect(normalizeVaultBasePath('nested/vault/'), '/nested/vault');
    expect(normalizeVaultBasePath('/'), '/');
  });
}
