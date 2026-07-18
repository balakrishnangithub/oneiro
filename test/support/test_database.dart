import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:oneiro/src/core/utils/date_x.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';

/// In-memory database for tests (backed by the OS sqlite3 on the host).
OneiroDatabase createTestDatabase() =>
    OneiroDatabase.withExecutor(NativeDatabase.memory());

/// Builds a complete companion for direct DAO inserts.
DreamEntriesCompanion buildEntry({
  required String id,
  required DateTime dreamDate,
  String text = 'A dream',
  bool isLucid = false,
  int createdAt = 1000,
}) {
  return DreamEntriesCompanion(
    id: Value(id),
    dreamDate: Value(dreamDate.dayMillis),
    body: Value(text),
    isLucid: Value(isLucid),
    createdAt: Value(createdAt),
    updatedAt: Value(createdAt),
  );
}
