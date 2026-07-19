import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../synced_entry.dart';

/// The OVault v2 archive: every journal entry (tombstones included) as one
/// gzip-compressed JSON document.
///
/// Layout before encryption:
///
/// ```json
/// { "v": 2, "entries": [ <SyncedEntry JSON>, ... ] }
/// ```
///
/// Entries are sorted by id so identical content produces byte-identical
/// documents (handy for tests and diffs). The gzip stream is what
/// `VaultCrypto.encryptBytes` seals into the envelope uploaded as
/// `archive.bin` — the server never sees plaintext or individual entry
/// boundaries.
///
/// Decode is strict: any schema violation throws [FormatException] so a
/// corrupted archive never half-applies. The sync engine treats a decode
/// failure as "quarantine and rebuild", never as "overwrite blindly".
class VaultArchive {
  VaultArchive._();

  static const version = 2;

  /// Serializes and gzip-compresses [entries] into the archive plaintext.
  static Uint8List encode(Iterable<SyncedEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.id.compareTo(b.id));
    final json = jsonEncode({
      'v': version,
      'entries': [for (final entry in sorted) entry.toJson()],
    });
    return Uint8List.fromList(GZipEncoder().encode(utf8.encode(json)));
  }

  /// Decompresses and strictly parses an archive produced by [encode].
  ///
  /// Throws [FormatException] when the bytes are not a valid v2 archive.
  static List<SyncedEntry> decode(Uint8List bytes) {
    final List<int> raw;
    try {
      raw = GZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FormatException('archive is not valid gzip: $error');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw const FormatException('archive payload is not valid JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('archive payload is not a JSON object');
    }
    if (decoded['v'] != version) {
      throw FormatException('unsupported archive version: ${decoded['v']}');
    }
    final entries = decoded['entries'];
    if (entries is! List) {
      throw const FormatException('archive "entries" must be a list');
    }
    return [
      for (final entry in entries)
        if (entry is Map<String, Object?>)
          SyncedEntry.fromJson(entry)
        else
          throw const FormatException('archive entry is not a JSON object'),
    ];
  }
}
