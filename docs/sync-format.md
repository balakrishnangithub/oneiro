# OVault v2 — Oneiro Encrypted Sync Format

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
└── archive.bin             one encrypted envelope holding ALL entries
```

v2 stores the whole journal in a single archive instead of v1's per-entry
files. Dreams are small texts, so one compressed upload is dramatically
faster than hundreds of WebDAV round-trips, leaks far less metadata (no
per-entry file names, sizes or timestamps), and keeps conflict handling
just as granular — the merge happens entry-by-entry **before** upload, not
by overwriting whole files.

## `vault.json` — descriptor

```json
{
  "format": "ovault",
  "v": 2,
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
The `v` field is the **format** version: v1 (per-entry files) clients reject
v2 descriptors and vice versa, so a mismatched client fails loudly instead of
silently misreading the vault.

## Key derivation

```
masterKey = scrypt(passphrase_utf8, salt, N=32768, r=8, p=1, dkLen=32)
```

The KDF parameters are recorded in the descriptor and honored at unlock time,
so they can be raised in future format revisions. (Tests use a much smaller
`N`; the value above is the pinned production default.)

## `archive.bin` — the encrypted archive

Envelope, UTF-8 JSON:

```json
{ "v": 2, "nonce": "<base64 12 bytes>", "ct": "<base64>" }
```

- A **fresh random 96-bit nonce** is generated for every upload.
- `ct` = `AES-256-GCM(masterKey, nonce, plaintext)` with the 16-byte
  authentication tag appended. Any tampering with `nonce` or `ct` fails
  authentication on decrypt.

### Plaintext (before encryption)

The plaintext is **gzip-compressed JSON** (compression before encryption —
ciphertext does not compress). Decompressed, it is canonical JSON with
entries sorted by id:

```json
{
  "v": 2,
  "entries": [
    {
      "id": "<uuid>",
      "dreamDate": 1778457600000,
      "body": "free text, may contain newlines",
      "isLucid": false,
      "createdAt": 1000,
      "updatedAt": 2000,
      "deletedAt": null
    }
  ]
}
```

All timestamps are Unix epoch milliseconds. `dreamDate` is day-granular.
`deletedAt != null` marks a **tombstone**: the entry was deleted on some
device; tombstones replicate deletions to other devices. The archive carries
every entry including tombstones, so it is a complete snapshot of the
journal's sync state.

### Atomic upload

`archive.bin` is always replaced atomically: the client uploads to a unique
temporary name (`archive.bin.upload-<uuid>`) and then renames (WebDAV
`MOVE`, or `rename(2)` for local folders) over `archive.bin`. A crash or
network drop mid-upload therefore never truncates the archive other devices
rely on; a leftover temp file is harmless.

## Synchronization algorithm

Conflict resolution is **last-write-wins** by `updatedAt` (documented,
deterministic; no merge of conflicting edits). Each device keeps a local
`sync_state` table: `entryId → lastSyncedUpdatedAt`.

For LWW to work, **every local mutation must bump `updatedAt`** — create,
edit, delete (`deletedAt` set) and undo-delete (`deletedAt` cleared) alike.
A mutation that keeps its old `updatedAt` is invisible to the merge: equal
timestamps are treated as identical content, so the change would never
reach the vault.

1. **Download** — fetch `archive.bin` if present and decrypt it into the
   remote entry set. A corrupted archive is **quarantined** (renamed to
   `archive.corrupted-<timestamp>.bin`, never overwritten), reported as a
   warning, and treated as empty; the merge below then rebuilds it from
   local state, and other devices re-merge anything only they had on their
   next sync.
2. **Reconcile duplicates** — ids are the merge's identity, but the same
   dream can originate twice under different ids (the classic case:
   importing the same Awoken file on two installs). A live local entry
   whose content signature (calendar day + normalized body, FNV-1a 64) also
   exists remotely under a different id is tombstoned locally — the
   archive's id wins, and the collapse uploads with the archive so every
   device the duplicate id reached heals too (reported as
   `duplicatesCollapsed`).
3. **Merge** — walk the union of local and remote ids:
   - remote missing → the local entry joins the upload set;
   - local missing → the remote payload is applied locally (upsert or
     soft-delete), then recorded in sync-state;
   - both present → the side with the newer `updatedAt` wins; a remote win
     is applied locally, a local win joins the upload set. Equal
     `updatedAt` is treated as identical content. When both sides changed
     since `lastSyncedUpdatedAt`, the run counts a resolved conflict.
4. **Upload** — only when the merged state differs from the remote archive:
   re-encode the full merged state (winners, tombstones included), gzip,
   encrypt and upload atomically. Pure-pull and no-change runs upload
   nothing. Local winners are recorded in sync-state only after the upload
   succeeds.
5. **Cleanup** — once a v2 archive exists remotely, the legacy v1
   `entries/` folder (if any) is removed.

Run counters follow the journal, not the wire: `pushed` / `pulled` /
`skipped` count live dreams only, while tombstones travel in
`deletionsPushed` / `deletionsPulled` (and stay silent once both sides
agree). A fresh install pulling a vault of 373 dreams plus 3 tombstones
therefore reports "pulled 373, 3 deletions".

Because every sync merges full state and uploads are atomic, an interrupted
sync is always safe: whatever was applied locally is recorded in sync-state,
and the next run (manual, app-start, or background) converges to the same
result.

## Threat model (honest summary)

**Protected:** entry contents, lucidity flags and all timestamps are encrypted
client-side with a key derived only from the user's passphrase. The server
operator, anyone with read access to the WebDAV folder, and network
eavesdroppers see only two files, one of them an opaque envelope. Per-entry
metadata (which entry changed when) is no longer visible at all — only the
archive's size and modification time.

**Not protected / out of scope:**

- *Metadata*: rough journal size and archive modification times.
- *Local device security*: the local journal database is unencrypted on disk
  (use the app's PIN lock and OS-level device encryption). If "remember
  passphrase" is enabled, the passphrase is stored in the platform credential
  vault (Android Keystore-backed).
- *Passphrase loss*: there is **no recovery**. Losing the passphrase means
  losing the remote copy.
- *Rollback attacks* by a malicious server (no signed history chain in v2).
  Last-write-wins on full state limits the damage to what a rollback itself
  contains; the next honest sync re-merges newer local data.
- Password strength: security reduces to passphrase entropy; scrypt slows but
  does not prevent brute-force of weak passphrases.
