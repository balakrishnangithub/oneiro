import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'remote_vault_store.dart';

/// The default vault folder on the server.
const defaultVaultBasePath = '/oneiro-vault';

/// Normalizes a user-supplied base path: leading slash, no trailing slash.
String normalizeVaultBasePath(String basePath) {
  var path = basePath.trim();
  if (path.isEmpty) return defaultVaultBasePath;
  if (!path.startsWith('/')) path = '/$path';
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

/// [RemoteVaultStore] over any WebDAV server (pCloud, Nextcloud, ...).
///
/// A thin wrapper around `package:webdav_client`: every method maps onto one
/// or two client calls, with 404 responses translated to null/empty so the
/// sync engine never has to know HTTP. The underlying [webdav.Client] is
/// constructor-injected for testability; use [WebdavVaultStore.connect] for
/// the normal basic-auth setup.
class WebdavVaultStore implements RemoteVaultStore {
  WebdavVaultStore(this._client, {String basePath = defaultVaultBasePath})
    : basePath = normalizeVaultBasePath(basePath);

  /// Builds a store with basic authentication against [url].
  factory WebdavVaultStore.connect({
    required String url,
    required String username,
    required String password,
    String basePath = defaultVaultBasePath,
  }) {
    return WebdavVaultStore(
      webdav.newClient(url, user: username, password: password),
      basePath: basePath,
    );
  }

  static const _uuid = Uuid();

  final webdav.Client _client;

  /// Vault folder on the server, normalized (leading slash, no trailing).
  final String basePath;

  String get _descriptorPath => '$basePath/vault.json';
  String get _archivePath => '$basePath/archive.bin';
  String get _legacyEntriesPath => '$basePath/entries/';

  bool _isNotFound(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  @override
  Future<void> ensureStructure() async {
    await _client.mkdirAll('$basePath/');
  }

  @override
  Future<String?> readDescriptor() async {
    try {
      final bytes = await _client.read(_descriptorPath);
      return utf8.decode(bytes);
    } catch (error) {
      if (_isNotFound(error)) return null;
      rethrow;
    }
  }

  @override
  Future<void> writeDescriptor(String contents) {
    return _client.write(
      _descriptorPath,
      Uint8List.fromList(utf8.encode(contents)),
    );
  }

  @override
  Future<Uint8List?> readArchive() async {
    try {
      final bytes = await _client.read(_archivePath);
      return Uint8List.fromList(bytes);
    } catch (error) {
      if (_isNotFound(error)) return null;
      rethrow;
    }
  }

  @override
  Future<void> writeArchiveAtomic(Uint8List bytes) async {
    // Unique temp name: two devices racing a sync must not clobber each
    // other's in-flight upload. The final MOVE is atomic on conformant
    // WebDAV servers, so readers only ever see a complete archive.
    final tempPath = '$basePath/archive.bin.upload-${_uuid.v4()}';
    await _client.write(tempPath, bytes);
    try {
      await _client.rename(tempPath, _archivePath, true);
    } catch (error) {
      // Best-effort temp sweep so a failed MOVE never leaves orphans.
      try {
        await _client.remove(tempPath);
      } catch (_) {
        // Already gone or server refused — nothing more to do.
      }
      rethrow;
    }
  }

  @override
  Future<void> quarantineArchive() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    try {
      await _client.rename(
        _archivePath,
        '$basePath/archive.corrupted-$stamp.bin',
        false,
      );
    } catch (error) {
      if (_isNotFound(error)) return;
      rethrow;
    }
  }

  @override
  Future<bool> deleteLegacyEntries() async {
    // removeAll() treats 404 as success, so probe first to keep the
    // "was anything actually removed?" answer honest.
    try {
      await _client.readDir(_legacyEntriesPath);
    } catch (error) {
      if (_isNotFound(error)) return false;
      rethrow;
    }
    await _client.removeAll(_legacyEntriesPath);
    return true;
  }
}
