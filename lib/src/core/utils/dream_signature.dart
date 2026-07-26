/// Content identity for journal entries, shared by import dedupe and sync
/// reconciliation.
///
/// A dream imported twice (re-import after a wipe, or import on two
/// devices) produces two database rows with different random ids — but they
/// are the SAME dream. This signature is how the app recognizes that: two
/// entries with the same calendar day and normalized body are considered
/// duplicates wherever they appear.
library;

/// Trims and collapses every run of whitespace to a single space, so
/// re-imported bodies compare equal regardless of line-wrap differences.
String normalizeBodyForDedupe(String body) =>
    body.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Deterministic content signature (FNV-1a, 64-bit) of one entry's calendar
/// day plus its normalized body. Stable across runs and devices, so
/// signatures computed from the database, from an import file, or from a
/// decrypted vault archive are directly comparable.
///
/// The arithmetic uses native Dart ints: VM ints are 64-bit two's-complement
/// and wrap on overflow, which is exactly the mod-2^64 FNV-1a recurrence —
/// no BigInt needed. (An earlier BigInt implementation allocated two BigInts
/// PER CHARACTER and froze the UI isolate for seconds during import.) Only
/// the final hex formatting goes through BigInt once, because a 64-bit
/// unsigned value whose top bit is set does not fit into a non-negative
/// Dart int. Golden output values are pinned by
/// `test/features/backup/awoken_import_service_test.dart`.
String dreamContentSignature(int dreamDateMillis, String body) {
  final input = '$dreamDateMillis\n${normalizeBodyForDedupe(body)}';
  var hash = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  const mask = 0xFFFFFFFFFFFFFFFF;
  for (final unit in input.codeUnits) {
    hash = ((hash ^ unit) * prime) & mask;
  }
  return BigInt.from(hash).toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
