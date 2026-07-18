import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_parser.dart';

/// Builds an export file in the exact Awoken grammar from hand-made blocks.
String awokenFile(List<String> entryBlocks, {String lineEnding = '\n'}) {
  final parts = <String>[
    'DREAMS FROM THE LUCID DREAMING TOOL - AWOKEN',
    '',
    'link: https://example.invalid/tool',
    '',
  ];
  for (final block in entryBlocks) {
    parts
      ..add('')
      ..add('----')
      ..add('')
      ..add(block);
  }
  return parts.join(lineEnding);
}

/// One `Date:`/`Lucidity:`/`Dream:` block (no leading separator).
String entryBlock({
  required String date,
  String lucidity = 'No',
  required String body,
}) => 'Date: $date\n\nLucidity: $lucidity\n\nDream:\n$body\n';

void main() {
  const parser = AwokenImportParser();

  group('standard grammar', () {
    test('parses multiple entries in file order', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(date: 'Mon 18 May 2026', body: 'Flying over the city'),
          entryBlock(
            date: 'Sun 10 May 2026',
            lucidity: 'Yes',
            body: 'I knew I was dreaming',
          ),
        ]),
      );

      expect(result.skippedCount, 0);
      expect(result.entries, hasLength(2));
      expect(result.entries[0].date, DateTime(2026, 5, 18));
      expect(result.entries[0].isLucid, isFalse);
      expect(result.entries[0].body, 'Flying over the city');
      expect(result.entries[1].date, DateTime(2026, 5, 10));
      expect(result.entries[1].isLucid, isTrue);
      expect(result.lucidCount, 1);
      expect(result.firstDate, DateTime(2026, 5, 10));
      expect(result.lastDate, DateTime(2026, 5, 18));
    });

    test('keeps multi-paragraph bodies intact', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(
            date: 'Mon 18 May 2026',
            body: 'First paragraph.\n\nSecond paragraph.\n\n\nThird.',
          ),
        ]),
      );

      expect(result.entries.single.body, 'First paragraph.\n\nSecond paragraph.\n\n\nThird.');
    });

    test('a line of three dashes inside a body does not split the entry', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(
            date: 'Mon 18 May 2026',
            body: 'Before the line\n---\nAfter the line',
          ),
        ]),
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.body, 'Before the line\n---\nAfter the line');
    });

    test('lines starting with spaces are body content', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(
            date: 'Mon 18 May 2026',
            body: '  indented note\n    ----  not a separator\nnormal line',
          ),
        ]),
      );

      expect(result.entries, hasLength(1));
      expect(
        result.entries.single.body,
        '  indented note\n    ----  not a separator\nnormal line',
      );
    });

    test('arbitrary Unicode (Tamil, emoji) survives', () {
      const body = 'நான் கனவில் பறந்தேன் 🌙✨ over the மலை';
      final result = parser.parse(
        awokenFile([entryBlock(date: 'Mon 18 May 2026', body: body)]),
      );

      expect(result.entries.single.body, body);
    });

    test('CRLF line endings parse identically to LF', () {
      final blocks = [
        entryBlock(date: 'Mon 18 May 2026', body: 'Line one\n\nLine two'),
        entryBlock(date: 'Fri 01 May 2026', lucidity: 'Yes', body: 'Other'),
      ];
      final lf = parser.parse(awokenFile(blocks));
      final crlf = parser.parse(awokenFile(blocks, lineEnding: '\r\n'));

      expect(crlf.entries, lf.entries);
      expect(crlf.skippedCount, 0);
    });
  });

  group('date liberalism', () {
    test('September parses as Sep, Sept and September', () {
      for (final month in ['Sep', 'Sept', 'September']) {
        final result = parser.parse(
          awokenFile([entryBlock(date: 'Sat 14 $month 2015', body: 'x')]),
        );
        expect(result.entries.single.date, DateTime(2015, 9, 14),
            reason: 'month spelling "$month"');
      }
    });

    test('a wrong weekday is tolerated', () {
      // 2026-05-18 was a Monday; claiming Friday must not reject the entry.
      final result = parser.parse(
        awokenFile([entryBlock(date: 'Fri 18 May 2026', body: 'x')]),
      );

      expect(result.entries.single.date, DateTime(2026, 5, 18));
    });

    test('zero-padded and bare days both parse', () {
      for (final day in ['01', '1']) {
        final result = parser.parse(
          awokenFile([entryBlock(date: 'Fri $day May 2026', body: 'x')]),
        );
        expect(result.entries.single.date, DateTime(2026, 5, 1));
      }
    });

    test('month names are case-insensitive', () {
      final result = parser.parse(
        awokenFile([entryBlock(date: 'Mon 18 mAY 2026', body: 'x')]),
      );
      expect(result.entries.single.date, DateTime(2026, 5, 18));
    });
  });

  group('malformed input', () {
    test('blocks missing Date or Dream labels are counted as skipped', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(date: 'Mon 18 May 2026', body: 'Good one'),
          'Lucidity: No\n\nDream:\nNo date here\n',
          'Date: Mon 18 May 2026\n\nLucidity: No\n', // no Dream: label
          'Date: someday\n\nDream:\nBad date\n',
          'Date: Mon 18 May 2026\n\nDream:\n\n', // empty body
        ]),
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.body, 'Good one');
      expect(result.skippedCount, 4);
      expect(result.warnings, hasLength(greaterThanOrEqualTo(4)));
    });

    test('missing Lucidity label warns and defaults to not lucid', () {
      final result = parser.parse(
        awokenFile(['Date: Mon 18 May 2026\n\nDream:\nbody\n']),
      );

      expect(result.entries, hasLength(1));
      expect(result.entries.single.isLucid, isFalse);
      expect(result.warnings.single, contains('Lucidity'));
    });

    test('unexpected lucidity value warns and defaults to not lucid', () {
      final result = parser.parse(
        awokenFile([
          entryBlock(date: 'Mon 18 May 2026', lucidity: 'Maybe', body: 'x'),
        ]),
      );

      expect(result.entries.single.isLucid, isFalse);
      expect(result.warnings.single, contains('Maybe'));
    });

    test('empty file yields no entries and a warning', () {
      for (final contents in ['', '   \n\n  ']) {
        final result = parser.parse(contents);
        expect(result.entries, isEmpty);
        expect(result.skippedCount, 0);
        expect(result.warnings, isNotEmpty);
      }
    });

    test('a file without separators warns instead of throwing', () {
      final result = parser.parse('just some random text\nnot an export\n');

      expect(result.entries, isEmpty);
      expect(result.warnings.single, contains('separators'));
    });

    test('garbage with separators never throws', () {
      final garbage = String.fromCharCodes(
        List.generate(512, (i) => (i * 37) % 0x3000),
      );
      final result = parser.parse('----\n$garbage\n----\n$garbage');

      expect(result.skippedCount, greaterThanOrEqualTo(1));
    });

    test('trailing blank tail after the last entry is ignored', () {
      final result = parser.parse(
        '${awokenFile([entryBlock(date: 'Mon 18 May 2026', body: 'x')])}\n\n\n',
      );

      expect(result.entries, hasLength(1));
      expect(result.skippedCount, 0);
    });
  });
}
