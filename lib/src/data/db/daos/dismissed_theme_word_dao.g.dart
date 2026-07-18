// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dismissed_theme_word_dao.dart';

// ignore_for_file: type=lint
mixin _$DismissedThemeWordDaoMixin on DatabaseAccessor<OneiroDatabase> {
  $DismissedThemeWordsTable get dismissedThemeWords =>
      attachedDatabase.dismissedThemeWords;
  DismissedThemeWordDaoManager get managers =>
      DismissedThemeWordDaoManager(this);
}

class DismissedThemeWordDaoManager {
  final _$DismissedThemeWordDaoMixin _db;
  DismissedThemeWordDaoManager(this._db);
  $$DismissedThemeWordsTableTableManager get dismissedThemeWords =>
      $$DismissedThemeWordsTableTableManager(
        _db.attachedDatabase,
        _db.dismissedThemeWords,
      );
}
