import 'dart:convert';

import '../../../data/db/oneiro_database.dart';

/// Full-fidelity JSON export of the journal.
///
/// Schema (`oneiro/journal-export`, version 1):
///
/// ```json
/// {
///   "format": "oneiro/journal-export",
///   "version": 1,
///   "app": "Oneiro",
///   "exportedAt": "2026-05-18T07:30:00.000Z",
///   "entryCount": 2,
///   "entries": [
///     {
///       "id": "client-generated-uuid",
///       "dreamDate": "2026-05-18",
///       "body": "free text, may be multi-line",
///       "isLucid": false,
///       "createdAt": "2026-05-19T08:00:00.000Z",
///       "updatedAt": "2026-05-19T08:00:00.000Z"
///     }
///   ]
/// }
/// ```
///
/// `dreamDate` is the local calendar day (`yyyy-MM-dd`); the two timestamps
/// are UTC ISO-8601 instants in milliseconds precision. Unlike the
/// Awoken-compatible text export, this format preserves ids and timestamps,
/// so it is the lossless backup option.
class JournalJsonExporter {
  const JournalJsonExporter({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const String format = 'oneiro/journal-export';
  static const int version = 1;

  final DateTime Function() _now;

  /// Pretty-printed JSON for [entries] (exported in the given order).
  String export(List<DreamEntry> entries) {
    final document = <String, Object?>{
      'format': format,
      'version': version,
      'app': 'Oneiro',
      'exportedAt': _now().toUtc().toIso8601String(),
      'entryCount': entries.length,
      'entries': [
        for (final entry in entries)
          <String, Object?>{
            'id': entry.id,
            'dreamDate': _formatDay(
              DateTime.fromMillisecondsSinceEpoch(entry.dreamDate),
            ),
            'body': entry.body,
            'isLucid': entry.isLucid,
            'createdAt': DateTime.fromMillisecondsSinceEpoch(
              entry.createdAt,
            ).toUtc().toIso8601String(),
            'updatedAt': DateTime.fromMillisecondsSinceEpoch(
              entry.updatedAt,
            ).toUtc().toIso8601String(),
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  static String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
