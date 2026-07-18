// Generates the README / store-listing screenshots headlessly.
//
// Pumps the real app (dark theme, real Roboto from tool/fonts/) against an
// in-memory database seeded with a believable journal, then captures each
// screen through a RepaintBoundary into docs/screenshots/.
//
// Run from the repo root:
//   flutter test tool/screenshots_test.dart
//
// Roboto lives in tool/fonts/ (Apache-2.0, see tool/fonts/README.md); without
// it the test environment renders text as placeholder boxes.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/app.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/journal/presentation/dream_editor_page.dart';
import 'package:oneiro/src/features/sync/sync_providers.dart';
import 'package:oneiro/src/features/training/training_providers.dart';

import '../test/support/fake_sync_services.dart';
import '../test/support/fake_training_services.dart';
import '../test/support/test_database.dart';
import '../test/support/unmount_app.dart';

const _boundaryKey = Key('screenshot-boundary');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Register real Roboto under its family name so default text styles
    // (fontFamily: null → Roboto on Android) resolve to actual glyphs.
    final loader = FontLoader('Roboto');
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      final bytes = await File('tool/fonts/Roboto-$weight.ttf').readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();

    // The framework's icon font is not auto-loaded outside the golden-file
    // pipeline; load it from the SDK cache or every Icon paints as a box.
    // Walk up from the test executable (flutter_tester / dart) until the SDK
    // layout gives itself away.
    const iconsRelPath =
        'bin/cache/artifacts/material_fonts/materialicons-regular.otf';
    var dir = File(Platform.resolvedExecutable).parent;
    var iconsFile = File('${dir.path}/$iconsRelPath');
    for (var i = 0; i < 8 && !iconsFile.existsSync(); i++) {
      dir = dir.parent;
      iconsFile = File('${dir.path}/$iconsRelPath');
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.view((await iconsFile.readAsBytes()).buffer)),
      );
    await icons.load();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: 2.625);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final out = File('docs/screenshots/$name.png');
    await out.create(recursive: true);
    await out.writeAsBytes(byteData!.buffer.asUint8List());
    // Surface the path in the test output for confirmation.
    // ignore: avoid_print
    print('wrote ${out.path}');
  }

  Future<void> pumpApp(WidgetTester tester, OneiroDatabase db) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oneiroDatabaseProvider.overrideWithValue(db),
          secureCredentialsStoreProvider.overrideWithValue(
            InMemorySecureCredentialsStore(),
          ),
          notificationGatewayProvider.overrideWithValue(
            FakeNotificationGateway(),
          ),
          notificationPermissionServiceProvider.overrideWithValue(
            FakeNotificationPermissionService(),
          ),
          cluePlayerProvider.overrideWithValue(FakeCluePlayer()),
        ],
        child: const RepaintBoundary(key: _boundaryKey, child: OneiroApp()),
      ),
    );
  }

  /// Real-async pumping until [finder] shows up (drift streams, router
  /// transitions and chart animations all need wall-clock frames).
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    int frames = 80,
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<void> settle(WidgetTester tester, {int frames = 60}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<OneiroDatabase> seededDatabase() async {
    final db = createTestDatabase();
    final now = DateTime.now();
    final entries = <(int daysAgo, String text, bool lucid)>[
      (
        0,
        'Flying low over the ocean at sunrise, steering by tilting my hands. '
            'The water was glass-clear and I could see coral below. '
            '#flying #ocean',
        true,
      ),
      (
        0,
        'At the old railway station waiting for a train that never arrives. '
            'Every announcement was in a language I almost knew. #trains',
        false,
      ),
      (
        1,
        "My grandmother's kitchen, but the doors kept multiplying. I counted "
            'them — seven — and knew that was wrong. #family #houses',
        true,
      ),
      (
        2,
        'Chased through an airport terminal by security for carrying a '
            '"suspicious sandwich". Woke up laughing. #chase #airport',
        false,
      ),
      (
        4,
        'Teeth crumbling while giving a presentation to a crowd of '
            'mannequins. Classic stress dream before the demo. #teeth #work',
        false,
      ),
      (
        6,
        'I asked a dream character what they represent. They said "the part '
            'of you that still writes dreams down" and handed me a notebook. '
            '#lucid #characters',
        true,
      ),
      (
        9,
        'Swimming with whales in a flooded city square. The bells underwater '
            'sounded like wind chimes. #ocean #city',
        false,
      ),
      (
        11,
        'Back in school, exam tomorrow, subject: "advanced cloud naming". '
            'I had revised none of the clouds. #school #exam',
        false,
      ),
      (
        13,
        'Walked through a mirror into the same room, but everything was '
            'slightly left-shifted. Realized I was dreaming and flew out of '
            'the window. #flying #mirrors',
        true,
      ),
    ];
    var created = 1000;
    for (final (index, entry) in entries.indexed) {
      created += 1000;
      await db.dreamEntryDao.insertEntry(
        buildEntry(
          id: 'shot-$index',
          dreamDate: now.subtract(Duration(days: entry.$1)),
          text: entry.$2,
          isLucid: entry.$3,
          createdAt: created,
        ),
      );
    }
    return db;
  }

  testWidgets('journal screen', (tester) async {
    final db = await seededDatabase();
    await tester.runAsync(() async {
      await pumpApp(tester, db);
      await waitFor(tester, find.textContaining('Flying low over the ocean'));
      await settle(tester, frames: 20);
      await capture(tester, '01-journal');
    });
    await unmountApp(tester);
    await db.close();
  });

  testWidgets('editor screen', (tester) async {
    final db = await seededDatabase();
    await tester.runAsync(() async {
      await pumpApp(tester, db);
      await waitFor(tester, find.text('Dream journal'));
      await tester.tap(find.byType(FloatingActionButton));
      await waitFor(tester, find.text('Record a dream'));
      await tester.enterText(
        find.descendant(
          of: find.byType(DreamEditorPage),
          matching: find.byType(TextField),
        ),
        'Standing on a rooftop garden above the clouds. The elevator buttons '
        'only had one floor: "up". I stepped off the edge and floated '
        'instead. #flying',
      );
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await settle(tester, frames: 20);
      await capture(tester, '02-editor');
    });
    await unmountApp(tester);
    await db.close();
  });

  testWidgets('patterns screen', (tester) async {
    final db = await seededDatabase();
    await tester.runAsync(() async {
      await pumpApp(tester, db);
      await waitFor(tester, find.text('Dream journal'));
      await tester.tap(find.text('Patterns'));
      await waitFor(tester, find.textContaining('flying'));
      await settle(tester, frames: 20);
      await capture(tester, '03-patterns');
    });
    await unmountApp(tester);
    await db.close();
  });

  testWidgets('progress screen', (tester) async {
    final db = await seededDatabase();
    await tester.runAsync(() async {
      await pumpApp(tester, db);
      await waitFor(tester, find.text('Dream journal'));
      await tester.tap(find.text('Progress'));
      await settle(tester); // charts animate over ~1.5 s
      await capture(tester, '04-progress');
    });
    await unmountApp(tester);
    await db.close();
  });

  testWidgets('settings screen', (tester) async {
    final db = await seededDatabase();
    await tester.runAsync(() async {
      await pumpApp(tester, db);
      await waitFor(tester, find.text('Dream journal'));
      await tester.tap(find.text('Settings'));
      await settle(tester, frames: 40);
      await capture(tester, '05-settings');
    });
    await unmountApp(tester);
    await db.close();
  });
}
