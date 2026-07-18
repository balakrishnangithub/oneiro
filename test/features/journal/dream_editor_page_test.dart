import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/core/utils/date_x.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/journal/presentation/dream_editor_page.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  testWidgets('saving a new dream writes it to the database', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DreamEditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record a dream'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Riding a slow train through the ocean',
    );

    // Flip the lucid switch on.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save dream'));
    await tester.pumpAndSettle();

    final entries = await db.dreamEntryDao.getActive();
    expect(entries, hasLength(1));
    expect(entries.single.body, 'Riding a slow train through the ocean');
    expect(entries.single.isLucid, isTrue);
    expect(
      entries.single.dreamDate,
      DateTime.now().dayMillis,
      reason: 'new dreams default to today',
    );
    expect(entries.single.deletedAt, isNull);

    await unmountApp(tester);
  });

  testWidgets('empty dreams are not saved', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DreamEditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save dream'));
    await tester.pumpAndSettle();

    expect(await db.dreamEntryDao.getActive(), isEmpty);
    expect(
      find.text('Write a few words about your dream first'),
      findsOneWidget,
    );

    // Let the snackbar's display timer run out so none is left pending.
    await tester.pump(const Duration(seconds: 5));
    await unmountApp(tester);
  });
}
