# OVault v1 — Oneiro Encrypted Sync Format

OVault is Oneiro's end-to-end encrypted synchronization format. Everything is
encrypted **on the device before upload**; the storage server only ever sees
opaque files. The design follows the same zero-knowledge philosophy as
Cryptomator, but it is an independent, simpler format.

> **OVault is NOT Cryptomator-compatible.** It cannot open Cryptomator vaults
> and Cryptomator cannot open OVault vaults. The formats differ in KDF,
> envelope layout, filename scheme and directory structure.

## Vault layout

```
<basePath>/                 (default: /oneiro-vault on WebDAV, or any local folder)
├── vault.json              unencrypted descriptor (no secrets)
└── entries/
    └── <entry-uuid>.json   one encrypted envelope per journal entry
```

File names are entry UUIDs; they reveal nothing about content. Deletions are
propagated as encrypted tombstones (see below), so the set of file names only
leaks the approximate number of journal entries over time.

## `vault.json` — descriptor

```json
{
  "format": "ovault",
  "v": 1,
  "kdf": { "algo": "scrypt", "N": 32768, "r": 8, "p": 1, "salt": "<base64>" },
  "check": "<base64>"
}
```

- `salt` — 16 random bytes, generated once at vault creation.
- `check` — `AES-256-GCM(masterKey, nonce=0^12, "ovault-key-check")` with the
  16-byte GCM tag appended. Proves knowledge of the master key without storing
  it. A wrong passphrase fails GCM authentication on this block, so unlock
  fails cleanly instead of producing garbage.

The descriptor contains no secret material and is safe to store in plaintext.

## Key derivation

```
masterKey = scrypt(passphrase_utf8, salt, N=32768, r=8, p=1, dkLen=32)
```

The KDF parameters are recorded in the descriptor and honored at unlock time,
so they can be raised in future format revisions. (Tests use a much smaller
`N`; the value above is the pinned production default.)

## Entry envelope (`entries/<uuid>.json`)

UTF-8 JSON:

```json
{ "v": 1, "nonce": "<base64 12 bytes>", "ct": "<base64>" }
```

- A **fresh random 96-bit nonce** is generated for every encryption.
- `ct` = `AES-256-GCM(masterKey, nonce, plaintext)` with the 16-byte
  authentication tag appended. Any tampering with `nonce` or `ct` fails
  authentication on decrypt.

### Plaintext (before encryption)

Canonical JSON (fixed key order):

```json
{
  "id": "<uuid>",
  "dreamDate": 1778457600000,
  "body": "free text, may contain newlines",
  "isLucid": false,
  "createdAt": 1000,
  "updatedAt": 2000,
  "deletedAt": null
}
```

All timestamps are Unix epoch milliseconds. `dreamDate` is day-granular.
`deletedAt != null` marks a **tombstone**: the entry was deleted on some
device; tombstones replicate deletions to other devices.

## Synchronization algorithm

One entry = one file. Conflict resolution is **last-write-wins** by
`updatedAt` (documented, deterministic; no merge of conflicting edits).

Each device keeps a local `sync_state` table:
`entryId → lastSyncedUpdatedAt`.

1. **Push** — every local entry (including tombstones) whose `updatedAt`
   differs from `lastSyncedUpdatedAt` is encrypted and uploaded; sync-state is
   updated afterwards.
2. **Pull** — every remote file whose entry is unknown locally, or whose
   decrypted `updatedAt` is newer than the local row's, is applied locally
   (upsert or soft-delete), then recorded in sync-state.
3. Per-file failures (corruption, I/O errors, undecryptable files) never abort
   the run; they are collected into `SyncReport.warnings` and the entry stays
   dirty for the next run.

## Threat model (honest summary)

**Protected:** entry contents, lucidity flags and all timestamps are encrypted
client-side with a key derived only from the user's passphrase. The server
operator, anyone with read access to the WebDAV folder, and network
eavesdroppers see only opaque envelopes.

**Not protected / out of scope:**

- *Metadata*: file count and rough vault size, access times visible to the
  server.
- *Local device security*: the local journal database is unencrypted on disk
  (use the app's PIN lock and OS-level device encryption). If "remember
  passphrase" is enabled, the passphrase is stored in the platform credential
  vault (Android Keystore-backed).
- *Passphrase loss*: there is **no recovery**. Losing the passphrase means
  losing the remote copy.
- *Rollback/reordering attacks* by a malicious server (no signed history
  chain in v1).
- Password strength: security reduces to passphrase entropy; scrypt slows but
  does not prevent brute-force of weak passphrases.
