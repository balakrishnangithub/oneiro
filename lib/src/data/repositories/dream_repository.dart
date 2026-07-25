import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../core/utils/date_x.dart';
import '../db/daos/dream_entry_dao.dart';
import '../db/oneiro_database.dart';

/// A not-yet-persisted journal entry for bulk creation.
///
/// Used by import flows ([DreamRepository.createEntries]): the caller
/// supplies only user data; ids and timestamps are filled in by the
/// repository exactly as [DreamRepository.createEntry] does.
typedef DreamEntryDraft = ({DateTime dreamDate, String text, bool isLucid});

/// Application-facing contract for dream-entry persistence.
///
/// Presentation code depends only on this interface, so later stages
/// (sync, import) can extend or wrap the implementation without
/// touching the UI.
abstract class DreamRepository {
  Stream<List<DreamEntry>> watchEntries({String query = ''});

  /// One-shot read of every live entry (used by backup export/import).
  Future<List<DreamEntry>> getAllActive();
  Future<DreamEntry?> getById(String id);
  Future<DreamEntry> createEntry({
    required DateTime dreamDate,
    required String text,
    required bool isLucid,
  });

  /// Bulk variant of [createEntry] for import flows: one transaction for the
  /// whole batch instead of one per entry.
  Future<void> createEntries(List<DreamEntryDraft> drafts);
  Future<void> updateEntry(DreamEntry entry);
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<int> countEntries();
  Future<int> countLucid();
}

/// [DreamRepository] backed by the local drift database.
class DriftDreamRepository implements DreamRepository {
  DriftDreamRepository(this._dao, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _now = clock ?? DateTime.now;

  final DreamEntryDao _dao;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Stream<List<DreamEntry>> watchEntries({String query = ''}) =>
      _dao.watchActive(query: query);

  @override
  Future<List<DreamEntry>> getAllActive() => _dao.getActive();

  @override
  Future<DreamEntry?> getById(String id) => _dao.getById(id);

  @override
  Future<DreamEntry> createEntry({
    required DateTime dreamDate,
    required String text,
    required bool isLucid,
  }) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final companion = DreamEntriesCompanion(
      id: Value(_uuid.v4()),
      dreamDate: Value(dreamDate.dayMillis),
      body: Value(text),
      isLucid: Value(isLucid),
      createdAt: Value(nowMs),
      updatedAt: Value(nowMs),
    );
    await _dao.insertEntry(companion);
    return (await _dao.getById(companion.id.value))!;
  }

  @override
  Future<void> createEntries(List<DreamEntryDraft> drafts) async {
    if (drafts.isEmpty) return;
    // One timestamp for the whole batch: import writes are one logical
    // event, and a shared createdAt/updatedAt keeps the merge logic simple.
    final nowMs = _now().millisecondsSinceEpoch;
    await _dao.insertAll([
      for (final draft in drafts)
        DreamEntriesCompanion(
          id: Value(_uuid.v4()),
          dreamDate: Value(draft.dreamDate.dayMillis),
          body: Value(draft.text),
          isLucid: Value(draft.isLucid),
          createdAt: Value(nowMs),
          updatedAt: Value(nowMs),
        ),
    ]);
  }

  @override
  Future<void> updateEntry(DreamEntry entry) {
    return _dao.updateEntry(
      entry.id,
      DreamEntriesCompanion(
        dreamDate: Value(entry.dreamDate),
        body: Value(entry.body),
        isLucid: Value(entry.isLucid),
        updatedAt: Value(_now().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) =>
      _dao.softDelete(id, _now().millisecondsSinceEpoch);

  @override
  Future<void> restore(String id) =>
      _dao.restore(id, _now().millisecondsSinceEpoch);

  @override
  Future<int> countEntries() => _dao.countActive();

  @override
  Future<int> countLucid() => _dao.countLucid();
}
