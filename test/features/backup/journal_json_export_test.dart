import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/repositories/dream_repository.dart';
import 'package:oneiro/src/features/backup/domain/journal_json_export.dart';

import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DriftDreamRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = DriftDreamRepository(
      db.dreamEntryDao,
      clock: () => DateTime(2026, 5, 20, 9, 0),
    );
  });

  tearDown(() async => db.close());

  test('exports the documented schema, pretty-printed and full fidelity', () async {
    final created = await repository.createEntry(
      dreamDate: DateTime(2026, 5, 18, 22, 30),
      text: 'Multi\nline 🌙',
      isLucid: true,
    );

    final exporter = JournalJsonExporter(
      clock: () => DateTime.utc(2026, 5, 20, 12, 0),
    );
    final text = exporter.export(await repository.getAllActive());

    // Pretty-printed: two-space indent.
    expect(text, contains('\n  "format"'));

    final document = jsonDecode(text) as Map<String, Object?>;
    expect(document['format'], 'oneiro/journal-export');
    expect(document['version'], 1);
    expect(document['app'], 'Oneiro');
    expect(document['exportedAt'], '2026-05-20T12:00:00.000Z');
    expect(document['entryCount'], 1);

    final entries = document['entries']! as List<Object?>;
    final entry = entries.single! as Map<String, Object?>;
    expect(entry['id'], created.id);
    expect(entry['dreamDate'], '2026-05-18');
    expect(entry['body'], 'Multi\nline 🌙');
    expect(entry['isLucid'], isTrue);
    expect(entry['createdAt'], isA<String>());
    expect(entry['updatedAt'], isA<String>());
  });

  test('empty journal exports a valid empty document', () {
    final text = const JournalJsonExporter().export(const []);
    final document = jsonDecode(text) as Map<String, Object?>;

    expect(document['entryCount'], 0);
    expect(document['entries'], isEmpty);
  });
}
