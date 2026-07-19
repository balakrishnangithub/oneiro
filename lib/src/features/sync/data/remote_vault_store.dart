import 'dart:typed_data';

/// Abstraction over the remote OVault storage location.
///
/// An OVault v2 vault is a folder containing two files:
///
/// - `vault.json` — unencrypted descriptor (KDF parameters + key-check
///   block; never any key material).
/// - `archive.bin` — one opaque OVault envelope holding the gzip-compressed
///   JSON archive of every journal entry, tombstones included.
///
/// Implementations must never see plaintext: `archive.bin` is produced by
/// `VaultCrypto` + `VaultArchive` before it reaches the store.
///
/// The two backends are WebDAV ([WebdavVaultStore]) and any local folder
/// ([LocalDirectoryVaultStore]) — the latter doubles as the test backend and
/// as a way to sync through a folder that an external tool (pCloud drive
/// sync, Syncthing, ...) mirrors.
abstract class RemoteVaultStore {
  /// Creates the vault folder if it does not exist yet.
  Future<void> ensureStructure();

  /// Raw `vault.json` contents, or null when the vault has not been
  /// initialized yet.
  Future<String?> readDescriptor();

  /// Writes the vault descriptor (called once, at vault creation).
  Future<void> writeDescriptor(String contents);

  /// The encrypted archive envelope, or null when absent remotely.
  Future<Uint8List?> readArchive();

  /// Uploads the encrypted archive atomically: the bytes land in a temporary
  /// file first and are then moved over `archive.bin`, so a crash or network
  /// drop mid-upload can never truncate the good archive the other devices
  /// rely on.
  Future<void> writeArchiveAtomic(Uint8List bytes);

  /// Moves a corrupted archive aside (`archive.bin` →
  /// `archive.corrupted-<stamp>.bin`) so the engine can rebuild from local
  /// data without destroying evidence. Succeeds when there is no archive.
  Future<void> quarantineArchive();

  /// Removes the legacy OVault v1 `entries/` folder (one encrypted file per
  /// entry), returning true when anything was removed. A no-op that returns
  /// false once the folder is gone — called after a v2 archive exists so the
  /// old per-entry files never outlive their replacement.
  Future<bool> deleteLegacyEntries();
}
