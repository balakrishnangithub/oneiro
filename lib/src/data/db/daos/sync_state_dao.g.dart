// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_state_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncStateDaoMixin on DatabaseAccessor<OneiroDatabase> {
  $SyncStatesTable get syncStates => attachedDatabase.syncStates;
  SyncStateDaoManager get managers => SyncStateDaoManager(this);
}

class SyncStateDaoManager {
  final _$SyncStateDaoMixin _db;
  SyncStateDaoManager(this._db);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db.attachedDatabase, _db.syncStates);
}
