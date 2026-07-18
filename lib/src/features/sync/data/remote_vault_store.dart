import 'dart:typed_data';

/// Abstraction over the remote OVault storage location.
///
/// A vault is a folder containing an unencrypted `vault.json` descriptor and
/// an `entries/` subfolder with one opaque encrypted file per journal entry
/// (`<id>.json`). Implementations must never see plaintext: everything under
/// `entries/` is an OVault envelope produced by `VaultCrypto`.
///
/// The two backends are WebDAV ([WebdavVaultStore]) and any local folder
/// ([LocalDirectoryVaultStore]) — the latter doubles as the test backend and
/// as a way to sync through a folder that an external tool (pCloud drive
/// sync, Syncthing, ...) mirrors.
abstract class RemoteVaultStore {
  /// Creates the vault folder structure if it does not exist yet.
  Future<void> ensureStructure();

  /// Raw `vault.json` contents, or null when the vault has not been
  /// initialized yet.
  Future<String?> readDescriptor();

  /// Writes the vault descriptor (called once, at vault creation).
  Future<void> writeDescriptor(String contents);

  /// Ids of all remotely stored entries (without the `.json` suffix).
  ///
  /// Returns an empty list when the entries folder does not exist yet.
  Future<List<String>> listEntryIds();

  /// The encrypted envelope for [id], or null when absent remotely.
  Future<Uint8List?> read(String id);

  /// Uploads (or overwrites) the encrypted envelope for [id].
  Future<void> write(String id, Uint8List bytes);

  /// Removes the remote file for [id]; succeeds when it is already gone.
  Future<void> delete(String id);
}
