import 'package:drift/drift.dart';

import '../oneiro_database.dart';
import '../tables.dart';

part 'sync_state_dao.g.dart';

/// Data-access object for [SyncStates], the sync dirty-tracking table.
@DriftAccessor(tables: [SyncStates])
class SyncStateDao extends DatabaseAccessor<OneiroDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  /// Every tracked entry as `entryId → lastSyncedUpdatedAt`.
  Future<Map<String, int>> getLastSyncedMap() async {
    final rows = await select(syncStates).get();
    return {for (final row in rows) row.entryId: row.lastSyncedUpdatedAt};
  }

  /// Records that [entryId] is now in sync at [updatedAt].
  Future<void> markSynced(String entryId, int updatedAt) {
    return into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion(
        entryId: Value(entryId),
        lastSyncedUpdatedAt: Value(updatedAt),
      ),
    );
  }
}
