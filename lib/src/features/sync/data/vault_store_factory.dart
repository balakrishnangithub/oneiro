import 'local_directory_vault_store.dart';
import 'remote_vault_store.dart';
import 'secure_credentials_store.dart';
import 'sync_settings_repository.dart';
import 'webdav_vault_store.dart';

/// Builds the [RemoteVaultStore] for [settings], or null when sync is not
/// configured yet (missing URL / folder path).
///
/// Shared by the Riverpod provider (foreground) and the WorkManager
/// background worker, so both resolve backends identically. WebDAV passwords
/// come from the credential vault, never from drift.
Future<RemoteVaultStore?> buildRemoteVaultStore(
  SyncConnectionSettings settings,
  SecureCredentialsStore secure,
) async {
  switch (settings.backendType) {
    case SyncBackendType.localFolder:
      final path = settings.localFolderPath.trim();
      if (path.isEmpty) return null;
      return LocalDirectoryVaultStore(path);
    case SyncBackendType.webdav:
      final url = settings.url.trim();
      if (url.isEmpty) return null;
      final password =
          await secure.read(SecureCredentialKeys.syncPassword) ?? '';
      return WebdavVaultStore.connect(
        url: url,
        username: settings.username,
        password: password,
        basePath: settings.basePath,
      );
  }
}
