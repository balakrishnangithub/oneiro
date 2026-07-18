import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/core/utils/date_x.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/journal/presentation/journal_page.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

Widget _wrap(OneiroDatabase db) {
  return ProviderScope(
    overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: JournalPage()),
  );
}

void main() {
  late OneiroDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  testWidgets('renders entries grouped under date headers', (tester) async {
    final dao = db.dreamEntryDao;
    await dao.insertEntry(
      buildEntry(
        id: 'lucid-one',
        dreamDate: DateTime(2026, 5, 18),
        text: 'Flying over a silent city',
        isLucid: true,
      ),
    );
    await dao.insertEntry(
      buildEntry(
        id: 'plain-one',
        dreamDate: DateTime(2026, 5, 17),
        text: 'A library with endless stairs',
      ),
    );

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text(formatDreamDate(DateTime(2026, 5, 18))),
      findsOneWidget,
    );
    expect(
      find.text(formatDreamDate(DateTime(2026, 5, 17))),
      findsOneWidget,
    );
    expect(find.text('Flying over a silent city'), findsOneWidget);
    expect(find.text('A library with endless stairs'), findsOneWidget);
    // Exactly one lucid moon marker.
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('shows an empty state when the journal is blank', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Your journal is still blank'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('search field filters the list', (tester) async {
    final dao = db.dreamEntryDao;
    await dao.insertEntry(
      buildEntry(
        id: 'a',
        dreamDate: DateTime(2026, 5, 18),
        text: 'Chased by a friendly whale',
      ),
    );
    await dao.insertEntry(
      buildEntry(
        id: 'b',
        dreamDate: DateTime(2026, 5, 17),
        text: 'Baking bread on the moon',
      ),
    );

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'whale');
    await tester.pumpAndSettle();

    expect(find.text('Chased by a friendly whale'), findsOneWidget);
    expect(find.text('Baking bread on the moon'), findsNothing);

    await unmountApp(tester);
  });
}
