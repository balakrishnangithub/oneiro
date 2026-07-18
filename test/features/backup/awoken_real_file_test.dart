import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_parser.dart';

/// Verification test against a real Awoken export file.
///
/// The real file is private (it contains actual dreams) and is therefore
/// NEVER committed to this repository. To run this test locally, point the
/// AWOKEN_EXPORT_PATH environment variable at the file, e.g.:
///
/// ```
/// AWOKEN_EXPORT_PATH='C:\path\to\awoken-export.txt' flutter test \
///   test/features/backup/awoken_real_file_test.dart
/// ```
///
/// Without the variable the test skips itself.
void main() {
  final path = Platform.environment['AWOKEN_EXPORT_PATH'];
  final file = path == null ? null : File(path);
  final available = file != null && file.existsSync();

  test(
    'parses the real export: 377 entries, 7 lucid, full date range',
    () {
      final contents = file!.readAsStringSync(encoding: utf8);
      final result = const AwokenImportParser().parse(contents);

      expect(result.skippedCount, 0, reason: result.warnings.join('\n'));
      expect(result.entries, hasLength(377));
      expect(result.lucidCount, 7);

      // File order: newest first.
      expect(result.entries.first.date, DateTime(2026, 5, 18));
      expect(result.entries.last.date, DateTime(2015, 11, 14));
      expect(result.lastDate, DateTime(2026, 5, 18));
      expect(result.firstDate, DateTime(2015, 11, 14));

      // Every entry has a non-empty body.
      expect(
        result.entries.where((e) => e.body.trim().isEmpty),
        isEmpty,
      );
    },
    skip: available
        ? false
        : 'set AWOKEN_EXPORT_PATH to a real Awoken export file to run',
  );
}
