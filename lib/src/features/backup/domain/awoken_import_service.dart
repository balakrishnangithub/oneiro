import '../../../core/utils/date_x.dart';
import '../../../core/utils/dream_signature.dart';
import '../../../data/repositories/dream_repository.dart';
import 'awoken_import_parser.dart';

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
