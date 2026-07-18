import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';

import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DriftSettingsRepository repository;

  setUp(() {
    db = createTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  group('defaults', () {
    test('empty store yields the documented defaults', () async {
      final settings = await repository.load();

      expect(settings, const TrainingSettings());
      expect(settings.realityChecksEnabled, isTrue);
      expect(settings.checksPerDay, 3);
      expect(settings.dayStartMinutes, 8 * 60);
      expect(settings.dayEndMinutes, 22 * 60);
      expect(settings.dayAlertSound, isTrue);
      expect(settings.dreamCluesEnabled, isFalse);
      expect(settings.cluesPerNight, 10);
      expect(settings.nightStartMinutes, 2 * 60 + 30);
      expect(settings.nightEndMinutes, 7 * 60 + 30);
      expect(settings.totemSound, TotemSound.chime);
      expect(settings.clueVolume, 0.45);
      expect(settings.morningReminderEnabled, isTrue);
      expect(settings.morningMinutes, 5 * 60);
      expect(settings.pausedUntil, isNull);
    });

    test('counters start at zero', () async {
      expect(await repository.realityCheckCount(), 0);
      expect(await repository.dreamClueCount(), 0);
    });
  });

  group('round trip', () {
    test('saved settings survive a reload, including the pause', () async {
      final pausedUntil = DateTime.fromMillisecondsSinceEpoch(1798765432000);
      final custom = TrainingSettings(
        realityChecksEnabled: false,
        checksPerDay: 7,
        dayStartMinutes: 6 * 60 + 15,
        dayEndMinutes: 23 * 60 + 45,
        dayAlertSound: false,
        dreamCluesEnabled: true,
        cluesPerNight: 14,
        nightStartMinutes: 23 * 60,
        nightEndMinutes: 5 * 60 + 30,
        totemSound: TotemSound.bell,
        clueVolume: 0.7,
        morningReminderEnabled: false,
        morningMinutes: 6 * 60 + 45,
        pausedUntil: pausedUntil,
      );

      await repository.save(custom);
      final loaded = await repository.load();

      expect(loaded, custom);
    });

    test('out-of-range values are clamped on save', () async {
      await repository.save(
        const TrainingSettings(checksPerDay: 42, clueVolume: 1.8),
      );
      final loaded = await repository.load();

      expect(loaded.checksPerDay, TrainingSettings.maxChecksPerDay);
      expect(loaded.clueVolume, 1.0);
    });

    test('watch() re-emits on every change', () async {
      final emissions = repository.watch().take(2).toList();

      await Future<void>.delayed(Duration.zero);
      await repository.save(const TrainingSettings(checksPerDay: 9));

      final values = await emissions;
      expect(values[0], const TrainingSettings());
      expect(values[1].checksPerDay, 9);
    });
  });

  group('counters', () {
    test('reality-check counter increments and persists', () async {
      expect(await repository.incrementRealityCheckCount(), 1);
      expect(await repository.incrementRealityCheckCount(), 2);
      expect(await repository.realityCheckCount(), 2);
      // The other counter is untouched.
      expect(await repository.dreamClueCount(), 0);
    });

    test('dream-clue counter increments independently', () async {
      expect(await repository.incrementDreamClueCount(), 1);
      expect(await repository.dreamClueCount(), 1);
      expect(await repository.realityCheckCount(), 0);
    });
  });
}
