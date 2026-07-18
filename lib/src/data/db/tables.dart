import 'package:drift/drift.dart';

/// A single dream-journal entry, keyed by calendar day.
///
/// [dreamDate] is a day-granularity timestamp (millis of local midnight).
/// [deletedAt] is a tombstone: rows are soft-deleted so a future sync stage
/// can propagate deletions before physically purging them.
class DreamEntries extends Table {
  /// Stable client-generated UUID.
  TextColumn get id => text()();

  /// Day-granularity dream date, millis since epoch of local midnight.
  IntColumn get dreamDate => integer()();

  /// Free-form dream body, may be multi-line.
  ///
  /// The SQL column is named `text`; the Dart getter is `body` because a
  /// getter named `text` would shadow the inherited `text()` column builder.
  TextColumn get body => text().named('text')();

  /// Whether the dreamer knew they were dreaming.
  BoolColumn get isLucid => boolean().withDefault(const Constant(false))();

  /// Creation time, millis since epoch.
  IntColumn get createdAt => integer()();

  /// Last modification time, millis since epoch.
  IntColumn get updatedAt => integer()();

  /// Soft-delete tombstone; null while the entry is live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Generic key-value settings store (theme, reminders, sync state, ...).
///
/// Stage A only creates the table; later stages own the keys written here.
class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
