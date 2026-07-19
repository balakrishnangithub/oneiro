import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/daos/dream_entry_dao.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';

import '../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DreamEntryDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = db.dreamEntryDao;
  });

  tearDown(() async => db.close());

  group('DreamEntryDao', () {
    test('watchActive returns entries newest dream-day first', () async {
      await dao.insertEntry(
        buildEntry(id: 'older', dreamDate: DateTime(2026, 5, 17)),
      );
      await dao.insertEntry(
        buildEntry(id: 'newer', dreamDate: DateTime(2026, 5, 18)),
      );

      final entries = await dao.watchActive().first;

      expect(entries.map((e) => e.id), ['newer', 'older']);
    });

    test('same-day entries fall back to createdAt, newest first', () async {
      await dao.insertEntry(
        buildEntry(
          id: 'morning',
          dreamDate: DateTime(2026, 5, 18),
          createdAt: 1000,
        ),
      );
      await dao.insertEntry(
        buildEntry(
          id: 'evening',
          dreamDate: DateTime(2026, 5, 18),
          createdAt: 2000,
        ),
      );

      final entries = await dao.getActive();

      expect(entries.map((e) => e.id), ['evening', 'morning']);
    });

    test('getById round-trips all columns', () async {
      await dao.insertEntry(
        buildEntry(
          id: 'a',
          dreamDate: DateTime(2026, 5, 18),
          text: 'Flying over rooftops',
          isLucid: true,
          createdAt: 42,
        ),
      );

      final entry = (await dao.getById('a'))!;

      expect(entry.body, 'Flying over rooftops');
      expect(entry.isLucid, isTrue);
      expect(entry.createdAt, 42);
      expect(entry.deletedAt, isNull);
    });

    test('updateEntry writes only the given columns', () async {
      await dao.insertEntry(
        buildEntry(
          id: 'a',
          dreamDate: DateTime(2026, 5, 18),
          text: 'Before',
          createdAt: 1,
        ),
      );

      await dao.updateEntry(
        'a',
        const DreamEntriesCompanion(body: Value('After')),
      );

      final entry = (await dao.getById('a'))!;
      expect(entry.body, 'After');
      expect(entry.createdAt, 1, reason: 'untouched columns stay put');
    });

    test('softDelete hides the entry, restore brings it back', () async {
      await dao.insertEntry(
        buildEntry(id: 'a', dreamDate: DateTime(2026, 5, 18)),
      );

      await dao.softDelete('a', 5000);

      expect(await dao.getActive(), isEmpty);
      expect(
        (await dao.getById('a'))!.deletedAt,
        5000,
        reason: 'row stays as a tombstone',
      );

      await dao.restore('a', 7000);

      expect(await dao.getActive(), hasLength(1));
      final restored = (await dao.getById('a'))!;
      expect(restored.deletedAt, isNull);
      expect(
        restored.updatedAt,
        7000,
        reason: 'restore must look newer than the tombstone for sync',
      );
    });

    test('search matches body text case-insensitively', () async {
      await dao.insertEntry(
        buildEntry(
          id: 'a',
          dreamDate: DateTime(2026, 5, 18),
          text: 'A lighthouse in the desert',
        ),
      );
      await dao.insertEntry(
        buildEntry(
          id: 'b',
          dreamDate: DateTime(2026, 5, 18),
          text: 'Underwater library',
        ),
      );

      final hits = await dao.getActive(query: 'LIGHTHOUSE');

      expect(hits.map((e) => e.id), ['a']);
    });

    test('search escapes LIKE wildcards and skips tombstoned rows', () async {
      await dao.insertEntry(
        buildEntry(
          id: 'a',
          dreamDate: DateTime(2026, 5, 18),
          text: '100% certain it was real',
        ),
      );
      await dao.insertEntry(
        buildEntry(
          id: 'b',
          dreamDate: DateTime(2026, 5, 18),
          text: 'certain of nothing',
        ),
      );
      await dao.softDelete('b', 1);

      final hits = await dao.getActive(query: '100%');

      expect(hits.map((e) => e.id), ['a']);
      expect(
        await dao.getActive(query: 'certain'),
        hasLength(1),
        reason: 'tombstoned rows never match',
      );
    });

    test('countActive and countLucid ignore tombstoned rows', () async {
      await dao.insertEntry(
        buildEntry(id: 'a', dreamDate: DateTime(2026, 5, 18), isLucid: true),
      );
      await dao.insertEntry(
        buildEntry(id: 'b', dreamDate: DateTime(2026, 5, 17)),
      );
      await dao.insertEntry(
        buildEntry(id: 'c', dreamDate: DateTime(2026, 5, 16), isLucid: true),
      );
      await dao.softDelete('c', 1);

      expect(await dao.countActive(), 2);
      expect(await dao.countLucid(), 1);
    });

    test('watchActive re-emits when data changes', () async {
      final events = <List<DreamEntry>>[];
      final subscription = dao.watchActive().listen(events.add);

      // Wait for the initial (empty) snapshot before mutating.
      await pumpEventQueue();
      await dao.insertEntry(
        buildEntry(id: 'a', dreamDate: DateTime(2026, 5, 18)),
      );
      await pumpEventQueue();

      expect(events, [isEmpty, hasLength(1)]);
      await subscription.cancel();
    });
  });
}
