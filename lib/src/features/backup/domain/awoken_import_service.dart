import '../../../core/utils/date_x.dart';
import '../../../data/repositories/dream_repository.dart';
import 'awoken_import_parser.dart';

/// Trims and collapses every run of whitespace to a single space, so
/// re-imported bodies compare equal regardless of line-wrap differences.
String normalizeBodyForDedupe(String body) =>
    body.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Deterministic content signature (FNV-1a, 64-bit) of one entry's calendar
/// day plus its normalized body. Two entries with the same signature are
/// considered duplicates. Stable across runs, so signatures computed from
/// the database and from an import file are directly comparable.
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

/// Outcome of an import run.
class AwokenImportOutcome {
  const AwokenImportOutcome({required this.imported, required this.duplicates});

  /// Entries actually written to the journal.
  final int imported;

  /// Entries skipped because an entry with the same day and normalized body
  /// already existed (in the journal or earlier in the same file).
  final int duplicates;
}

/// Imports parsed Awoken entries into the journal, skipping duplicates.
///
/// Duplication is decided by [dreamContentSignature]: one bulk pre-check
/// loads the signatures of every live journal entry, so re-importing the
/// same export file imports 0 entries without per-entry queries.
///
/// Non-duplicate entries are collected first and written in ONE bulk insert
/// ([DreamRepository.createEntries]) — hundreds of individually awaited
/// inserts visibly stalled the import on real devices.
class AwokenImportService {
  const AwokenImportService(this._repository);

  final DreamRepository _repository;

  /// Imports [parsed] entries, reporting progress as
  /// `(processed, total)` after each block. Already-known entries are
  /// skipped, and duplicates inside the file itself collapse too.
  Future<AwokenImportOutcome> importEntries(
    List<AwokenImportedEntry> parsed, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final existing = await _repository.getAllActive();
    final seen = existing
        .map((entry) => dreamContentSignature(entry.dreamDate, entry.body))
        .toSet();

    var imported = 0;
    var duplicates = 0;
    final drafts = <DreamEntryDraft>[];
    for (var i = 0; i < parsed.length; i++) {
      final entry = parsed[i];
      final signature = dreamContentSignature(entry.date.dayMillis, entry.body);
      if (seen.contains(signature)) {
        duplicates++;
      } else {
        seen.add(signature);
        drafts.add((
          dreamDate: entry.date,
          text: entry.body,
          isLucid: entry.isLucid,
        ));
        imported++;
      }
      onProgress?.call(i + 1, parsed.length);
    }
    await _repository.createEntries(drafts);
    return AwokenImportOutcome(imported: imported, duplicates: duplicates);
  }
}
