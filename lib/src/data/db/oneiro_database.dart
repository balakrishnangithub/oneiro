import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/dismissed_theme_word_dao.dart';
import 'daos/dream_entry_dao.dart';
import 'daos/sync_state_dao.dart';
import 'tables.dart';

part 'oneiro_database.g.dart';

/// Oneiro's local database.
///
/// The default constructor opens the on-device database; use
/// [OneiroDatabase.withExecutor] in tests to inject an in-memory database.
@DriftDatabase(
  tables: [DreamEntries, AppSettings, DismissedThemeWords, SyncStates],
  daos: [DreamEntryDao, DismissedThemeWordDao, SyncStateDao],
)
class OneiroDatabase extends _$OneiroDatabase {
  OneiroDatabase() : super(_openConnection());

  OneiroDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // v2: dismissed theme words for the patterns feature.
    // v3: per-entry sync bookkeeping for the encrypted sync feature.
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(dismissedThemeWords);
      }
      if (from < 3) {
        await migrator.createTable(syncStates);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'oneiro');
  }
}
