import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';

/// Persists the "hide app in recents" preference in `app_settings`.
///
/// The default is ON: a dream journal is exactly the kind of app whose
/// content should never peek out of the app switcher. The key is only
/// written once the user toggles the switch, so fresh installs stay on the
/// secure default without a migration.
class ScreenPrivacyRepository {
  ScreenPrivacyRepository(this._db);

  static const String key = 'privacy.screenSecure';

  final OneiroDatabase _db;

  Future<bool> load() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    // Default ON unless the user explicitly turned it off.
    return row?.value != 'false';
  }

  Stream<bool> watch() =>
      (_db.select(_db.appSettings)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value != 'false');

  Future<void> save(bool secure) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(key: const Value(key), value: Value('$secure')),
        );
  }
}
