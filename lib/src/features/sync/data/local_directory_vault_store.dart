import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

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

  static final _safeId = RegExp(r'^[A-Za-z0-9._-]+$');

  File get _descriptorFile => File(p.join(_root.path, 'vault.json'));
  Directory get _entriesDir => Directory(p.join(_root.path, 'entries'));

  File _entryFile(String id) {
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'unsafe vault entry id');
    }
    return File(p.join(_entriesDir.path, '$id.json'));
  }

  @override
  Future<void> ensureStructure() async {
    await _entriesDir.create(recursive: true);
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
  Future<List<String>> listEntryIds() async {
    if (!await _entriesDir.exists()) return const [];
    final ids = <String>[];
    await for (final entity in _entriesDir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.json')) continue;
      ids.add(name.substring(0, name.length - '.json'.length));
    }
    ids.sort();
    return ids;
  }

  @override
  Future<Uint8List?> read(String id) async {
    try {
      return await _entryFile(id).readAsBytes();
    } on PathNotFoundException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await ensureStructure();
    await _entryFile(id).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _entryFile(id).delete();
    } on PathNotFoundException {
      // Already gone — deletion is idempotent.
    } on FileSystemException {
      // Already gone — deletion is idempotent.
    }
  }
}
