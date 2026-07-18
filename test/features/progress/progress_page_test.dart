import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/progress/presentation/progress_page.dart';
import 'package:oneiro/src/features/progress/progress_providers.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/domain/training_settings.dart';
import 'package:oneiro/src/features/training/training_providers.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

/// Counters-only fake; settings themselves are unused by the progress page.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.realityChecks = 0, this.dreamClues = 0});

  int realityChecks;
  int dreamClues;

  @override
  Future<int> realityCheckCount() async => realityChecks;

  @override
  Future<int> dreamClueCount() async => dreamClues;

  @override
  Future<int> incrementRealityCheckCount() async => ++realityChecks;

  @override
  Future<int> incrementDreamClueCount() async => ++dreamClues;

  @override
  Future<TrainingSettings> load() async => const TrainingSettings();

  @override
  Future<void> save(TrainingSettings settings) async {}

  @override
  Stream<TrainingSettings> watch() =>
      Stream.value(const TrainingSettings());
}

Widget _wrap(OneiroDatabase db, {required DateTime today}) {
  return ProviderScope(
    overrides: [
      oneiroDatabaseProvider.overrideWithValue(db),
      todayProvider.overrideWithValue(today),
      settingsRepositoryProvider.overrideWithValue(
        FakeSettingsRepository(realityChecks: 30, dreamClues: 12),
      ),
    ],
    child: const MaterialApp(home: ProgressPage()),
  );
}

void main() {
  late OneiroDatabase db;
  final today = DateTime(2026, 5, 18);

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  testWidgets('renders stat cards, chart and milestones', (tester) async {
    // Enlarge the viewport so the lazy ListView builds every section.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dao = db.dreamEntryDao;
    await dao.insertEntry(
      buildEntry(
        id: 'a',
        dreamDate: today,
        text: 'flying over the city at dawn',
        isLucid: true,
      ),
    );
    await dao.insertEntry(
      buildEntry(
        id: 'b',
        dreamDate: today.subtract(const Duration(days: 1)),
        text: 'lost in a library',
      ),
    );

    await tester.pumpWidget(_wrap(db, today: today));
    await tester.pumpAndSettle();

    // Stat cards (labels also appear as achievement track titles).
    expect(find.text('Journal entries'), findsNWidgets(2));
    expect(find.text('Lucid dreams'), findsNWidgets(2));
    expect(find.text('Lucid rate'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    // Current and longest streak are both two days.
    expect(find.text('2 days'), findsNWidgets(2));

    // Weekly chart.
    expect(find.text('Entries per week'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    // Achievements with counters from the fake settings repository.
    expect(find.text('Dreamwalker milestones'), findsOneWidget);
    expect(find.text('Reality checks'), findsOneWidget);
    expect(find.text('30 / 100'), findsOneWidget);
    expect(find.text('Dream clues heard'), findsOneWidget);
    expect(find.text('12 / 50'), findsOneWidget);
    expect(find.text('First Awakening · Next: Lucid Spark'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('empty journal shows zeros without crashing', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(db, today: today));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);
    // Entries and lucid counters are at zero towards their first milestone.
    expect(find.text('0 / 1'), findsNWidgets(2));
    expect(find.textContaining('Next: First Ink'), findsOneWidget);

    await unmountApp(tester);
  });
}
