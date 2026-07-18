// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dream_entry_dao.dart';

// ignore_for_file: type=lint
mixin _$DreamEntryDaoMixin on DatabaseAccessor<OneiroDatabase> {
  $DreamEntriesTable get dreamEntries => attachedDatabase.dreamEntries;
  DreamEntryDaoManager get managers => DreamEntryDaoManager(this);
}

class DreamEntryDaoManager {
  final _$DreamEntryDaoMixin _db;
  DreamEntryDaoManager(this._db);
  $$DreamEntriesTableTableManager get dreamEntries =>
      $$DreamEntriesTableTableManager(_db.attachedDatabase, _db.dreamEntries);
}
