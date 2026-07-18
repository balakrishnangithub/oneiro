import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/backup/backup_providers.dart';
import 'package:oneiro/src/features/backup/data/import_file_picker.dart';
import 'package:oneiro/src/features/backup/presentation/backup_section.dart';

import '../../support/fake_backup_services.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

const twoEntryFile = '''
DREAMS FROM THE LUCID DREAMING TOOL - AWOKEN

link: https://example.invalid/tool

----

Date: Mon 18 May 2026

Lucidity: No

Dream:
Flying over the city

----

Date: Sun 10 May 2026

Lucidity: Yes

Dream:
I knew I was dreaming

''';

void main() {
  late OneiroDatabase db;
  late FakeImportFilePicker picker;
  late FakeBackupShareGateway gateway;

  setUp(() {
    db = createTestDatabase();
    picker = FakeImportFilePicker(
      next: const PickedImportFile(name: 'dreams.txt', contents: twoEntryFile),
    );
    gateway = FakeBackupShareGateway();
  });

  tearDown(() async => db.close());

  Widget wrap() => ProviderScope(
    overrides: [
      oneiroDatabaseProvider.overrideWithValue(db),
      importFilePickerProvider.overrideWithValue(picker),
      backupShareGatewayProvider.overrideWithValue(gateway),
    ],
    child: const MaterialApp(home: Scaffold(body: BackupSection())),
  );

  testWidgets('preview → confirm → result, and re-import dedupes', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Start the import: picker is consulted, preview appears.
    await tester.tap(find.text('Import from Awoken export'));
    await tester.pumpAndSettle();

    expect(picker.pickCount, 1);
    expect(find.text('Import preview'), findsOneWidget);
    expect(find.text('dreams.txt'), findsOneWidget);
    expect(find.text('2 entries found'), findsOneWidget);
    expect(find.text('1 lucid'), findsOneWidget);
    expect(find.textContaining('18 May 2026'), findsOneWidget);
    expect(find.textContaining('10 May 2026'), findsOneWidget);

    // Confirm: progress dialog runs, then the result dialog summarizes.
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Import complete'), findsOneWidget);
    expect(
      find.text('Imported 2, skipped 0 duplicates, 0 unreadable.'),
      findsOneWidget,
    );
    expect(await db.dreamEntryDao.countActive(), 2);
    expect(await db.dreamEntryDao.countLucid(), 1);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Re-importing the same file skips everything as duplicates.
    await tester.tap(find.text('Import from Awoken export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(
      find.text('Imported 0, skipped 2 duplicates, 0 unreadable.'),
      findsOneWidget,
    );
    expect(await db.dreamEntryDao.countActive(), 2);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await unmountApp(tester);
  });

  testWidgets('cancelling the preview writes nothing', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from Awoken export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await db.dreamEntryDao.countActive(), 0);

    await unmountApp(tester);
  });

  testWidgets('cancelling the picker does nothing', (tester) async {
    picker.next = null;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from Awoken export'));
    await tester.pumpAndSettle();

    expect(find.text('Import preview'), findsNothing);
    expect(await db.dreamEntryDao.countActive(), 0);

    await unmountApp(tester);
  });

  testWidgets('text export shares an Awoken-compatible file', (tester) async {
    await db.dreamEntryDao.insertEntry(
      buildEntry(id: 'a', dreamDate: DateTime(2026, 5, 18), text: 'Flying'),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export as Awoken-compatible text'));
    await tester.pumpAndSettle();

    expect(gateway.shared, hasLength(1));
    final share = gateway.shared.single;
    expect(share.fileName, endsWith('.txt'));
    expect(share.contents, contains('Date: Mon 18 May 2026'));
    expect(share.contents, contains('Dream:\nFlying'));

    await unmountApp(tester);
  });

  testWidgets('JSON export shares a full-fidelity document', (tester) async {
    await db.dreamEntryDao.insertEntry(
      buildEntry(
        id: 'a',
        dreamDate: DateTime(2026, 5, 18),
        text: 'Flying',
        isLucid: true,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export as JSON'));
    await tester.pumpAndSettle();

    expect(gateway.shared, hasLength(1));
    final share = gateway.shared.single;
    expect(share.fileName, endsWith('.json'));
    expect(share.contents, contains('"format": "oneiro/journal-export"'));
    expect(share.contents, contains('"id": "a"'));
    expect(share.contents, contains('"dreamDate": "2026-05-18"'));
    expect(share.contents, contains('"isLucid": true'));

    await unmountApp(tester);
  });

  testWidgets('exporting an empty journal shows a snackbar instead', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export as JSON'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to export yet'), findsOneWidget);
    expect(gateway.shared, isEmpty);

    await unmountApp(tester);
  });
}
