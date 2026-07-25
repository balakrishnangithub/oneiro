import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/repositories/dream_repository.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_parser.dart';
import 'package:oneiro/src/features/backup/domain/awoken_import_service.dart';

import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DriftDreamRepository repository;
  late AwokenImportService service;

  AwokenImportedEntry parsed(
    DateTime date,
    String body, {
    bool lucid = false,
  }) => AwokenImportedEntry(date: date, isLucid: lucid, body: body);

  setUp(() {
    db = createTestDatabase();
    repository = DriftDreamRepository(
      db.dreamEntryDao,
      clock: () => DateTime(2026, 5, 20, 9, 0),
    );
    service = AwokenImportService(repository);
  });

  tearDown(() async => db.close());

  group('dreamContentSignature', () {
    // Golden values produced by the ORIGINAL BigInt implementation — the
    // native-int rewrite must keep dedupe stable across app upgrades, or
    // every already-imported entry would look new and duplicate on re-import.
    test('matches the golden values of the original BigInt implementation', () {
      expect(
        dreamContentSignature(1778457600000, 'Flying over an ocean of stars'),
        'e8ec6a7195a31dd6',
      );
      expect(
        dreamContentSignature(
          1447459200000,
          '  multi\nline   body\twith whitespace  ',
        ),
        'b9f0a29fbd40d43f',
      );
      expect(
        dreamContentSignature(0, 'üñïcødé — emojis 🌙✨'),
        '6a0e6028daf95ea1',
      );
    });

    test('high-bit results render as unsigned 16-digit hex', () {
      for (final body in ['a', 'b', 'x', 'hello', 'test']) {
        final signature = dreamContentSignature(1778457600000, body);
        expect(signature, hasLength(16));
        expect(signature, matches(RegExp(r'^[0-9a-f]{16}$')));
      }
    });
  });

  group('AwokenImportService', () {
    test('imports all entries into an empty journal', () async {
      final outcome = await service.importEntries([
        parsed(DateTime(2026, 5, 18), 'Flying'),
        parsed(DateTime(2026, 5, 17), 'Swimming', lucid: true),
      ]);

      expect(outcome.imported, 2);
      expect(outcome.duplicates, 0);

      final stored = await repository.getAllActive();
      expect(stored, hasLength(2));
      expect(stored.first.body, 'Flying'); // newest dream day first
      expect(stored.first.isLucid, isFalse);
      expect(stored.last.isLucid, isTrue);
    });

    test('re-importing the same file imports 0 (bulk pre-check)', () async {
      final entries = [
        parsed(DateTime(2026, 5, 18), 'Flying'),
        parsed(DateTime(2026, 5, 17), 'Swimming', lucid: true),
        parsed(DateTime(2026, 5, 16), 'Falling'),
      ];

      final first = await service.importEntries(entries);
      expect(first.imported, 3);

      final second = await service.importEntries(entries);
      expect(second.imported, 0);
      expect(second.duplicates, 3);
      expect(await repository.countEntries(), 3);
    });

    test('duplicates are detected after whitespace normalization', () async {
      await service.importEntries([parsed(DateTime(2026, 5, 18), 'a   b\nc')]);

      final outcome = await service.importEntries([
        parsed(DateTime(2026, 5, 18), ' a b c '),
      ]);

      expect(outcome.imported, 0);
      expect(outcome.duplicates, 1);
    });

    test('duplicates inside one file collapse to a single entry', () async {
      final outcome = await service.importEntries([
        parsed(DateTime(2026, 5, 18), 'same'),
        parsed(DateTime(2026, 5, 18), 'same'),
      ]);

      expect(outcome.imported, 1);
      expect(outcome.duplicates, 1);
      expect(await repository.countEntries(), 1);
    });

    test('same body on a different day is not a duplicate', () async {
      final outcome = await service.importEntries([
        parsed(DateTime(2026, 5, 18), 'same'),
        parsed(DateTime(2026, 5, 17), 'same'),
      ]);

      expect(outcome.imported, 2);
      expect(outcome.duplicates, 0);
    });

    test('tombstoned entries do not block re-import', () async {
      await service.importEntries([parsed(DateTime(2026, 5, 18), 'gone')]);
      final stored = await repository.getAllActive();
      await repository.softDelete(stored.single.id);

      final outcome = await service.importEntries([
        parsed(DateTime(2026, 5, 18), 'gone'),
      ]);

      expect(outcome.imported, 1);
      expect(await repository.countEntries(), 1);
    });

    test('progress callback reports processed counts', () async {
      final calls = <(int, int)>[];
      await service.importEntries([
        parsed(DateTime(2026, 5, 18), 'a'),
        parsed(DateTime(2026, 5, 17), 'b'),
      ], onProgress: (done, total) => calls.add((done, total)));

      expect(calls, [(1, 2), (2, 2)]);
    });
  });
}
