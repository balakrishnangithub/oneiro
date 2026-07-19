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

  test('ensureStructure creates the vault folder and is idempotent', () async {
    await store.ensureStructure();
    expect(tempDir.existsSync(), isTrue);
    await store.ensureStructure(); // second call is a no-op
    expect(tempDir.existsSync(), isTrue);
  });

  test('descriptor round-trips; absent descriptor reads as null', () async {
    expect(await store.readDescriptor(), isNull);
    await store.writeDescriptor('{"format":"ovault"}');
    expect(await store.readDescriptor(), '{"format":"ovault"}');
  });

  test('archive round-trips; absent archive reads as null', () async {
    expect(await store.readArchive(), isNull);
    await store.writeArchiveAtomic(Uint8List.fromList([1, 2, 3]));
    expect(await store.readArchive(), [1, 2, 3]);
  });

  test('atomic write leaves no temp files and overwrites cleanly', () async {
    await store.writeArchiveAtomic(Uint8List.fromList([9]));
    await store.writeArchiveAtomic(Uint8List.fromList([7, 7]));
    expect(await store.readArchive(), [7, 7]);

    final leftover = tempDir
        .listSync()
        .where((e) => e.path.contains('.upload-'))
        .toList();
    expect(leftover, isEmpty);
  });

  test('quarantine renames the archive and is a no-op when absent', () async {
    await store.quarantineArchive(); // no archive: nothing happens
    expect(await store.readArchive(), isNull);

    await store.writeArchiveAtomic(Uint8List.fromList([5]));
    await store.quarantineArchive();
    expect(await store.readArchive(), isNull);
    final quarantined = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('archive.corrupted-'))
        .toList();
    expect(quarantined, hasLength(1));
    expect(await quarantined.single.readAsBytes(), [5]);
  });

  test('deleteLegacyEntries reports whether anything was removed', () async {
    expect(await store.deleteLegacyEntries(), isFalse);

    final legacy = Directory('${tempDir.path}/entries');
    await legacy.create();
    await File('${legacy.path}/some-id.json').writeAsBytes([1]);
    expect(await store.deleteLegacyEntries(), isTrue);
    expect(legacy.existsSync(), isFalse);

    // Gone now: second call reports nothing removed.
    expect(await store.deleteLegacyEntries(), isFalse);
  });

  test('normalizeVaultBasePath enforces leading slash, strips trailing', () {
    expect(normalizeVaultBasePath(''), defaultVaultBasePath);
    expect(normalizeVaultBasePath('vault'), '/vault');
    expect(normalizeVaultBasePath('/vault/'), '/vault');
    expect(normalizeVaultBasePath('nested/vault/'), '/nested/vault');
    expect(normalizeVaultBasePath('/'), '/');
  });
}
