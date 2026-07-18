import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/patterns/presentation/patterns_page.dart';

import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

Widget _wrap(OneiroDatabase db) {
  return ProviderScope(
    overrides: [oneiroDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: PatternsPage()),
  );
}

void main() {
  late OneiroDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() async => db.close());

  Future<void> seedDreams() async {
    final dao = db.dreamEntryDao;
    await dao.insertEntry(
      buildEntry(
        id: 'a',
        dreamDate: DateTime(2026, 5, 18),
        text: 'flying with whales over the ocean #flying',
        isLucid: true,
      ),
    );
    await dao.insertEntry(
      buildEntry(
        id: 'b',
        dreamDate: DateTime(2026, 5, 17),
        text: 'flying through storm clouds',
      ),
    );
  }

  testWidgets('lists theme words with counts, hashtags styled', (tester) async {
    await seedDreams();

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('flying'), findsOneWidget);
    expect(find.text('appears 2 times'), findsOneWidget);
    expect(find.text('#flying'), findsOneWidget);
    // #flying, whales, ocean, storm, clouds each appear once.
    expect(find.text('appears once'), findsNWidgets(5));

    await unmountApp(tester);
  });

  testWidgets('empty journal shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text('Write more dreams to reveal your patterns'),
      findsOneWidget,
    );

    await unmountApp(tester);
  });

  testWidgets('lucid-only filter narrows the analysis', (tester) async {
    await seedDreams();

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lucid only'));
    await tester.pumpAndSettle();

    // From the non-lucid entry only.
    expect(find.text('storm'), findsNothing);
    expect(find.text('clouds'), findsNothing);
    // From the lucid entry.
    expect(find.text('whales'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('dismissing a word removes it and persists', (tester) async {
    await seedDreams();

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('whales'), findsOneWidget);

    final whalesTile = find.ancestor(
      of: find.text('whales'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: whalesTile,
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('whales'), findsNothing);
    expect(await db.dismissedThemeWordDao.getDismissed(), {'whales'});

    await unmountApp(tester);
  });

  testWidgets('previously dismissed words never surface again', (tester) async {
    await seedDreams();
    await db.dismissedThemeWordDao.dismiss('whales', 1000);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('whales'), findsNothing);
    expect(find.text('flying'), findsOneWidget);

    await unmountApp(tester);
  });
}
