import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'remote_vault_store.dart';

/// [RemoteVaultStore] over a plain local folder.
///
/// Two purposes:
///
/// 1. Full end-to-end sync tests without any server.
/// 2. A genuinely useful backend for users: point the vault at any folder a
///    sync tool (pCloud drive sync, Syncthing, Dropbox, a mounted drive)
///    already mirrors, and the journal replicates through it — encrypted
///    exactly like the WebDAV backend.
class LocalDirectoryVaultStore implements RemoteVaultStore {
  LocalDirectoryVaultStore(String rootPath) : _root = Directory(rootPath);

  final Directory _root;

  static const _uuid = Uuid();

  File get _descriptorFile => File(p.join(_root.path, 'vault.json'));
  File get _archiveFile => File(p.join(_root.path, 'archive.bin'));
  Directory get _legacyEntriesDir => Directory(p.join(_root.path, 'entries'));

  @override
  Future<void> ensureStructure() async {
    await _root.create(recursive: true);
  }

  @override
  Future<String?> readDescriptor() async {
    try {
      return await _descriptorFile.readAsString();
    } on PathNotFoundException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writeDescriptor(String contents) async {
    await ensureStructure();
    await _descriptorFile.writeAsString(contents, flush: true);
  }

  @override
  Future<Uint8List?> readArchive() async {
    try {
      return await _archiveFile.readAsBytes();
    } on PathNotFoundException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> writeArchiveAtomic(Uint8List bytes) async {
    await ensureStructure();
    final temp = File(p.join(_root.path, 'archive.bin.upload-${_uuid.v4()}'));
    await temp.writeAsBytes(bytes, flush: true);
    // Rename within the same directory is atomic on every supported OS.
    await temp.rename(_archiveFile.path);
  }

  @override
  Future<void> quarantineArchive() async {
    if (!await _archiveFile.exists()) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await _archiveFile.rename(
      p.join(_root.path, 'archive.corrupted-$stamp.bin'),
    );
  }

  @override
  Future<bool> deleteLegacyEntries() async {
    if (!await _legacyEntriesDir.exists()) return false;
    await _legacyEntriesDir.delete(recursive: true);
    return true;
  }
}
