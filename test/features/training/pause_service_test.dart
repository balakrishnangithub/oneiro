import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/domain/pause_service.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';

import '../../support/test_database.dart';

void main() {
  late OneiroDatabase db;
  late DriftSettingsRepository repository;
  final now = DateTime(2026, 5, 18, 12, 0);

  PauseService makeService() => PauseService(repository, clock: () => now);

  setUp(() {
    db = createTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  test('training is active by default', () async {
    final settings = await repository.load();
    expect(PauseService.isPaused(settings, now), isFalse);
  });

  test('pauseFor sets pausedUntil relative to the clock', () async {
    await makeService().pauseFor(3);

    final settings = await repository.load();
    expect(settings.pausedUntil, now.add(const Duration(days: 3)));
    expect(PauseService.isPaused(settings, now), isTrue);
    expect(
      PauseService.isPaused(
        settings,
        now.add(const Duration(days: 3, seconds: 1)),
      ),
      isFalse,
    );
  });

  test('resume clears the pause', () async {
    await makeService().pauseFor(7);
    await makeService().resume();

    final settings = await repository.load();
    expect(settings.pausedUntil, isNull);
    expect(PauseService.isPaused(settings, now), isFalse);
  });

  test('resume on an unpaused store is a no-op', () async {
    await makeService().resume();
    expect(await repository.load(), const TrainingSettings());
  });
}
