import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/training/data/settings_repository.dart';
import 'package:oneiro/src/features/training/presentation/reality_check_page.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;
  late DriftSettingsRepository repository;

  Widget wrap() {
    return ProviderScope(
      overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: RealityCheckPage()),
    );
  }

  setUp(() {
    db = createTestDatabase();
    repository = DriftSettingsRepository(db);
  });

  tearDown(() async => db.close());

  testWidgets('"I\'m awake" increments the counter and confirms', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm awake"));
    await tester.pumpAndSettle();

    expect(await repository.realityCheckCount(), 1);
    expect(find.text('Logged.'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(RealityCheckPage), findsNothing);

    await unmountApp(tester);
  });

  testWidgets('"I was dreaming" also counts as a completed check', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('I was dreaming'));
    await tester.pumpAndSettle();

    expect(await repository.realityCheckCount(), 1);
    expect(find.text('Logged.'), findsOneWidget);

    await unmountApp(tester);
  });
}
