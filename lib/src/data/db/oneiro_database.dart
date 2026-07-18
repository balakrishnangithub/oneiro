import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/dream_entry_dao.dart';
import 'tables.dart';

part 'oneiro_database.g.dart';

/// Oneiro's local database.
///
/// The default constructor opens the on-device database; use
/// [OneiroDatabase.withExecutor] in tests to inject an in-memory database.
@DriftDatabase(tables: [DreamEntries, AppSettings], daos: [DreamEntryDao])
class OneiroDatabase extends _$OneiroDatabase {
  OneiroDatabase() : super(_openConnection());

  OneiroDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'oneiro');
  }
}
