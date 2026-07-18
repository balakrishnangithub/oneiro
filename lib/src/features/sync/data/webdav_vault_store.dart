import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
/// A thin wrapper around `package:webdav_client`: every method maps straight
/// onto one client call, with 404 responses translated to null/empty so the
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

  final webdav.Client _client;

  /// Vault folder on the server, normalized (leading slash, no trailing).
  final String basePath;

  String get _descriptorPath => '$basePath/vault.json';
  String get _entriesPath => '$basePath/entries';
  String _entryPath(String id) => '$_entriesPath/$id.json';

  bool _isNotFound(Object error) =>
      error is DioException && error.response?.statusCode == 404;

  @override
  Future<void> ensureStructure() async {
    await _client.mkdirAll('$basePath/');
    await _client.mkdirAll('$_entriesPath/');
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
  Future<List<String>> listEntryIds() async {
    final List<webdav.File> files;
    try {
      files = await _client.readDir('$_entriesPath/');
    } catch (error) {
      if (_isNotFound(error)) return const [];
      rethrow;
    }
    final ids = <String>[
      for (final file in files)
        if (file.isDir == false &&
            file.name != null &&
            file.name!.endsWith('.json'))
          file.name!.substring(0, file.name!.length - '.json'.length),
    ];
    ids.sort();
    return ids;
  }

  @override
  Future<Uint8List?> read(String id) async {
    try {
      final bytes = await _client.read(_entryPath(id));
      return Uint8List.fromList(bytes);
    } catch (error) {
      if (_isNotFound(error)) return null;
      rethrow;
    }
  }

  @override
  Future<void> write(String id, Uint8List bytes) {
    return _client.write(_entryPath(id), bytes);
  }

  @override
  Future<void> delete(String id) {
    // The client's remove() already treats 404 as success.
    return _client.remove(_entryPath(id));
  }
}
