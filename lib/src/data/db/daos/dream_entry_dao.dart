import 'package:drift/drift.dart';

import '../oneiro_database.dart';
import '../tables.dart';

part 'dream_entry_dao.g.dart';

/// Escapes the SQL `LIKE` wildcards `%` and `_` in user input.
String escapeLikePattern(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

/// Data-access object for [DreamEntries].
///
/// Everything here ignores tombstoned rows unless it explicitly operates on
/// the tombstone itself ([softDelete], [restore]).
@DriftAccessor(tables: [DreamEntries])
class DreamEntryDao extends DatabaseAccessor<OneiroDatabase>
    with _$DreamEntryDaoMixin {
  DreamEntryDao(super.db);

  Selectable<DreamEntry> _activeQuery({String query = ''}) {
    final statement = select(dreamEntries)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.dreamDate),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final pattern = '%${escapeLikePattern(trimmed)}%';
      statement.where((t) => t.body.like(pattern, escapeChar: r'\'));
    }
    return statement;
  }

  /// All live entries, newest dream day first, matching [query]
  /// (case-insensitive substring on the body text).
  Stream<List<DreamEntry>> watchActive({String query = ''}) =>
      _activeQuery(query: query).watch();

  /// One-shot variant of [watchActive].
  Future<List<DreamEntry>> getActive({String query = ''}) =>
      _activeQuery(query: query).get();

  /// Finds an entry by id, live or tombstoned.
  Future<DreamEntry?> getById(String id) =>
      (select(dreamEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Every entry including tombstones — the full replication set for sync.
  Future<List<DreamEntry>> getAllIncludingDeleted() =>
      select(dreamEntries).get();

  /// Applies a remote entry verbatim (sync pull): inserts or replaces all
  /// columns, including the tombstone, without touching timestamps.
  Future<void> upsertFromSync(DreamEntriesCompanion entry) =>
      into(dreamEntries).insertOnConflictUpdate(entry);

  Future<void> insertEntry(DreamEntriesCompanion entry) =>
      into(dreamEntries).insert(entry);

  /// Writes only the columns present in [changes] to the entry [id].
  Future<int> updateEntry(String id, DreamEntriesCompanion changes) =>
      (update(dreamEntries)..where((t) => t.id.equals(id))).write(changes);

  /// Tombstones the entry [id] at [deletedAtMs] instead of removing the row.
  Future<int> softDelete(String id, int deletedAtMs) =>
      (update(dreamEntries)..where((t) => t.id.equals(id))).write(
        DreamEntriesCompanion(
          deletedAt: Value(deletedAtMs),
          updatedAt: Value(deletedAtMs),
        ),
      );

  /// Clears the tombstone of entry [id] (undo of [softDelete]).
  Future<int> restore(String id) =>
      (update(dreamEntries)..where((t) => t.id.equals(id))).write(
        const DreamEntriesCompanion(deletedAt: Value(null)),
      );

  Future<int> _count(Expression<bool> filter) {
    final amount = countAll(filter: filter);
    final query = selectOnly(dreamEntries)..addColumns([amount]);
    return query.map((row) => row.read(amount)!).getSingle();
  }

  /// Number of live entries.
  Future<int> countActive() => _count(dreamEntries.deletedAt.isNull());

  /// Number of live entries marked lucid.
  Future<int> countLucid() => _count(
    dreamEntries.deletedAt.isNull() & dreamEntries.isLucid.equals(true),
  );
}
