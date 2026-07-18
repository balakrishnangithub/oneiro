import 'package:drift/drift.dart';

import '../../../data/db/oneiro_database.dart';
import '../domain/training_settings.dart';
import '../domain/training_settings_store.dart';

/// Application-facing contract for training settings and counters.
///
/// Everything is stored in the generic `app_settings` key/value table; this
/// repository gives it a typed façade and a change stream for the UI.
abstract class SettingsRepository implements TrainingSettingsStore {
  /// Live stream of the current settings, re-emitting on every change.
  Stream<TrainingSettings> watch();

  /// Reality checks completed from the reality-check dialog.
  Future<int> realityCheckCount();

  /// Dream clues played (totem sound actually triggered).
  Future<int> dreamClueCount();

  /// Atomically increments and returns the reality-check counter.
  Future<int> incrementRealityCheckCount();

  /// Atomically increments and returns the dream-clue counter.
  Future<int> incrementDreamClueCount();
}

/// [SettingsRepository] backed by the drift `app_settings` table.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db);

  final OneiroDatabase _db;

  // --- Keys -----------------------------------------------------------------

  static const _kRealityChecksEnabled = 'training.realityChecksEnabled';
  static const _kChecksPerDay = 'training.checksPerDay';
  static const _kDayStartMinutes = 'training.dayStartMinutes';
  static const _kDayEndMinutes = 'training.dayEndMinutes';
  static const _kDayAlertSound = 'training.dayAlertSound';
  static const _kDreamCluesEnabled = 'training.dreamCluesEnabled';
  static const _kCluesPerNight = 'training.cluesPerNight';
  static const _kNightStartMinutes = 'training.nightStartMinutes';
  static const _kNightEndMinutes = 'training.nightEndMinutes';
  static const _kTotemSound = 'training.totemSound';
  static const _kClueVolume = 'training.clueVolume';
  static const _kMorningReminderEnabled = 'training.morningReminderEnabled';
  static const _kMorningMinutes = 'training.morningMinutes';
  static const _kPausedUntilMs = 'training.pausedUntilMs';

  static const _kRealityCheckCount = 'counters.realityCheckCount';
  static const _kDreamClueCount = 'counters.dreamClueCount';

  // --- Decode / encode ------------------------------------------------------

  static const _defaults = TrainingSettings();

  static bool _bool(Map<String, String> m, String key, bool fallback) =>
      m[key] == null ? fallback : m[key] == 'true';

  static int _int(Map<String, String> m, String key, int fallback) =>
      int.tryParse(m[key] ?? '') ?? fallback;

  static double _double(Map<String, String> m, String key, double fallback) =>
      double.tryParse(m[key] ?? '') ?? fallback;

  static TrainingSettings _decode(Map<String, String> m) {
    final pausedMs = _int(m, _kPausedUntilMs, 0);
    return TrainingSettings(
      realityChecksEnabled: _bool(
        m,
        _kRealityChecksEnabled,
        _defaults.realityChecksEnabled,
      ),
      checksPerDay: _int(m, _kChecksPerDay, _defaults.checksPerDay),
      dayStartMinutes: _int(m, _kDayStartMinutes, _defaults.dayStartMinutes),
      dayEndMinutes: _int(m, _kDayEndMinutes, _defaults.dayEndMinutes),
      dayAlertSound: _bool(m, _kDayAlertSound, _defaults.dayAlertSound),
      dreamCluesEnabled: _bool(
        m,
        _kDreamCluesEnabled,
        _defaults.dreamCluesEnabled,
      ),
      cluesPerNight: _int(m, _kCluesPerNight, _defaults.cluesPerNight),
      nightStartMinutes: _int(
        m,
        _kNightStartMinutes,
        _defaults.nightStartMinutes,
      ),
      nightEndMinutes: _int(m, _kNightEndMinutes, _defaults.nightEndMinutes),
      totemSound: TotemSound.fromName(m[_kTotemSound]),
      clueVolume: _double(m, _kClueVolume, _defaults.clueVolume),
      morningReminderEnabled: _bool(
        m,
        _kMorningReminderEnabled,
        _defaults.morningReminderEnabled,
      ),
      morningMinutes: _int(m, _kMorningMinutes, _defaults.morningMinutes),
      pausedUntil: pausedMs == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pausedMs),
    ).normalized();
  }

  static Map<String, String> _encode(TrainingSettings s) => {
    _kRealityChecksEnabled: '${s.realityChecksEnabled}',
    _kChecksPerDay: '${s.checksPerDay}',
    _kDayStartMinutes: '${s.dayStartMinutes}',
    _kDayEndMinutes: '${s.dayEndMinutes}',
    _kDayAlertSound: '${s.dayAlertSound}',
    _kDreamCluesEnabled: '${s.dreamCluesEnabled}',
    _kCluesPerNight: '${s.cluesPerNight}',
    _kNightStartMinutes: '${s.nightStartMinutes}',
    _kNightEndMinutes: '${s.nightEndMinutes}',
    _kTotemSound: s.totemSound.name,
    _kClueVolume: '${s.clueVolume}',
    _kMorningReminderEnabled: '${s.morningReminderEnabled}',
    _kMorningMinutes: '${s.morningMinutes}',
    _kPausedUntilMs: '${s.pausedUntil?.millisecondsSinceEpoch ?? 0}',
  };

  // --- Low-level access -----------------------------------------------------

  Future<Map<String, String>> _readAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> _put(String key, String value) {
    return _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  // --- SettingsRepository ---------------------------------------------------

  @override
  Stream<TrainingSettings> watch() => _db
      .select(_db.appSettings)
      .watch()
      .map((rows) => _decode({for (final row in rows) row.key: row.value}));

  @override
  Future<TrainingSettings> load() async => _decode(await _readAll());

  @override
  Future<void> save(TrainingSettings settings) {
    final encoded = _encode(settings.normalized());
    return _db.transaction(() async {
      for (final entry in encoded.entries) {
        await _put(entry.key, entry.value);
      }
    });
  }

  Future<int> _counter(String key) async => _int(await _readAll(), key, 0);

  Future<int> _increment(String key) async {
    return _db.transaction(() async {
      final next = (await _counter(key)) + 1;
      await _put(key, '$next');
      return next;
    });
  }

  @override
  Future<int> realityCheckCount() => _counter(_kRealityCheckCount);

  @override
  Future<int> dreamClueCount() => _counter(_kDreamClueCount);

  @override
  Future<int> incrementRealityCheckCount() => _increment(_kRealityCheckCount);

  @override
  Future<int> incrementDreamClueCount() => _increment(_kDreamClueCount);
}
