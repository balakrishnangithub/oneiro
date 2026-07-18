import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/features/backup/domain/awoken_exporter.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_parser.dart';

void main() {
  const exporter = AwokenExporter();
  const parser = AwokenImportParser();

  final sampleEntries = [
    AwokenImportedEntry(
      date: DateTime(2026, 5, 18),
      isLucid: false,
      body: 'Flying over the city',
    ),
    AwokenImportedEntry(
      date: DateTime(2026, 5, 1),
      isLucid: true,
      body: 'Multi\n\nparagraph\n---\nbody 🌙',
    ),
    AwokenImportedEntry(
      date: DateTime(2015, 11, 14),
      isLucid: false,
      body: 'நான் கனவில்',
    ),
  ];

  group('AwokenExporter', () {
    test('round-trip: parse(export(entries)) == entries', () {
      final result = parser.parse(exporter.export(sampleEntries));

      expect(result.skippedCount, 0);
      expect(result.warnings, isEmpty);
      expect(result.entries, sampleEntries);
    });

    test('round-trip is stable through a second export', () {
      final once = exporter.export(sampleEntries);
      final twice = exporter.export(parser.parse(once).entries);

      expect(twice, once);
    });

    test('emits the exact grammar shape', () {
      final text = exporter.export([sampleEntries.first]);
      final lines = text.split('\n');

      expect(lines[0], 'DREAMS FROM THE LUCID DREAMING TOOL - ONEIRO');
      expect(lines[1], '');
      expect(lines[2], startsWith('link: '));
      expect(lines[3], '');
      expect(lines[4], '');
      expect(lines[5], '----');
      expect(lines[6], '');
      // 2026-05-18 was a Monday; the weekday must match the date.
      expect(lines[7], 'Date: Mon 18 May 2026');
      expect(lines[8], '');
      expect(lines[9], 'Lucidity: No');
      expect(lines[10], '');
      expect(lines[11], 'Dream:');
      expect(lines[12], 'Flying over the city');
    });

    test('separator precedes every entry including the first', () {
      final text = exporter.export(sampleEntries);
      final separators = RegExp(r'^----$', multiLine: true).allMatches(text);

      expect(separators, hasLength(sampleEntries.length));
    });

    test('September renders as Sep with a matching weekday', () {
      // 2015-09-14 was a Monday.
      final text = exporter.export([
        AwokenImportedEntry(
          date: DateTime(2015, 9, 14),
          isLucid: false,
          body: 'x',
        ),
      ]);

      expect(text, contains('Date: Mon 14 Sep 2015'));
      // And the parser accepts what we emit.
      expect(parser.parse(text).entries.single.date, DateTime(2015, 9, 14));
    });

    test('zero-pads single-digit days', () {
      final text = exporter.export([sampleEntries[1]]);
      expect(text, contains('Date: Fri 01 May 2026'));
    });

    test('lucid entries render Lucidity: Yes', () {
      final text = exporter.export([sampleEntries[1]]);
      expect(text, contains('Lucidity: Yes'));
    });

    test('empty journal exports a header-only file that parses to nothing', () {
      final result = parser.parse(exporter.export(const []));

      expect(result.entries, isEmpty);
      expect(result.skippedCount, 0);
    });
  });
}
