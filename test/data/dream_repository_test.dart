import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/core/utils/date_x.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/repositories/dream_repository.dart';

import '../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DriftDreamRepository repository;

  // Fixed clock so timestamps are deterministic.
  DateTime fakeNow = DateTime(2026, 5, 18, 7, 30);

  setUp(() {
    db = createTestDatabase();
    repository = DriftDreamRepository(db.dreamEntryDao, clock: () => fakeNow);
  });

  tearDown(() async => db.close());

  group('DriftDreamRepository', () {
    test('createEntry assigns id, day-normalized date and timestamps', () async {
      final entry = await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18, 23, 45),
        text: 'Walking through walls',
        isLucid: true,
      );

      expect(entry.id, isNotEmpty);
      expect(entry.dreamDate, DateTime(2026, 5, 18).dayMillis);
      expect(entry.body, 'Walking through walls');
      expect(entry.isLucid, isTrue);
      expect(entry.createdAt, fakeNow.millisecondsSinceEpoch);
      expect(entry.updatedAt, entry.createdAt);
      expect(entry.deletedAt, isNull);
    });

    test('ids are unique across entries', () async {
      final a = await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18),
        text: 'One',
        isLucid: false,
      );
      final b = await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18),
        text: 'Two',
        isLucid: false,
      );

      expect(a.id, isNot(b.id));
    });

    test('updateEntry bumps updatedAt but keeps createdAt', () async {
      final entry = await repository.createEntry(
        dreamDate: DateTime(2026, 5, 17),
        text: 'Original',
        isLucid: false,
      );

      fakeNow = DateTime(2026, 5, 19, 8, 0);
      await repository.updateEntry(
        entry.copyWith(body: 'Rewritten', isLucid: true),
      );

      final updated = (await repository.getById(entry.id))!;
      expect(updated.body, 'Rewritten');
      expect(updated.isLucid, isTrue);
      expect(updated.createdAt, entry.createdAt);
      expect(updated.updatedAt, fakeNow.millisecondsSinceEpoch);
    });

    test('softDelete and restore round-trip through the stream', () async {
      final entry = await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18),
        text: 'Temporary',
        isLucid: false,
      );

      expect(await repository.countEntries(), 1);

      await repository.softDelete(entry.id);
      expect(await repository.countEntries(), 0);
      expect((await repository.getById(entry.id))!.deletedAt, isNotNull);

      await repository.restore(entry.id);
      expect(await repository.countEntries(), 1);
    });

    test('counts track lucid entries', () async {
      await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18),
        text: 'Lucid one',
        isLucid: true,
      );
      await repository.createEntry(
        dreamDate: DateTime(2026, 5, 17),
        text: 'Ordinary one',
        isLucid: false,
      );

      expect(await repository.countEntries(), 2);
      expect(await repository.countLucid(), 1);
    });

    test('watchEntries passes the search query through', () async {
      await repository.createEntry(
        dreamDate: DateTime(2026, 5, 18),
        text: 'Teeth turning to sand',
        isLucid: false,
      );
      await repository.createEntry(
        dreamDate: DateTime(2026, 5, 17),
        text: 'A calm meadow',
        isLucid: false,
      );

      final hits = await repository.watchEntries(query: 'sand').first;

      expect(hits, hasLength(1));
      expect(hits.single.body, contains('sand'));
    });
  });
}
