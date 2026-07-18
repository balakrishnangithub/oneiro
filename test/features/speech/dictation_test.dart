import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneiro/src/data/db/oneiro_database.dart';
import 'package:oneiro/src/data/providers.dart';
import 'package:oneiro/src/features/journal/presentation/dream_editor_page.dart';
import 'package:oneiro/src/features/speech/speech_providers.dart';

import '../../support/fake_speech_recognizer.dart';
import '../../support/test_database.dart';
import '../../support/unmount_app.dart';

void main() {
  late OneiroDatabase db;
  late FakeSpeechRecognizer recognizer;

  setUp(() {
    db = createTestDatabase();
    recognizer = FakeSpeechRecognizer();
  });

  tearDown(() async => db.close());

  Widget wrap() => ProviderScope(
    overrides: [
      oneiroDatabaseProvider.overrideWithValue(db),
      speechRecognizerProvider.overrideWithValue(recognizer),
    ],
    child: const MaterialApp(home: DreamEditorPage()),
  );

  String editorText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('dictation appends recognized phrases with a space between '
      'utterances, then saves with the dream', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dictate dream'));
    await tester.pumpAndSettle();

    expect(recognizer.initializeCalls, 1);
    expect(recognizer.startCalls, 1);
    expect(find.text('Listening… speak your dream'), findsOneWidget);

    // Partial results render live but are not committed yet.
    recognizer.emit('a boat made of glass');
    await tester.pump();
    expect(editorText(tester), 'a boat made of glass');

    // A narrower partial replaces the previous one (same utterance).
    recognizer.emit('a boat made of');
    await tester.pump();
    expect(editorText(tester), 'a boat made of');

    // Final commits the utterance; the next utterance gets one space.
    recognizer.emit('a boat made of glass', isFinal: true);
    await tester.pump();
    recognizer.emit('sailing over the city', isFinal: true);
    await tester.pump();
    expect(editorText(tester), 'a boat made of glass sailing over the city');

    await tester.tap(find.byTooltip('Stop dictation'));
    await tester.pumpAndSettle();
    expect(recognizer.stopCalls, 1);
    expect(find.text('Listening… speak your dream'), findsNothing);

    await tester.tap(find.byTooltip('Save dream'));
    await tester.pumpAndSettle();
    final entries = await db.dreamEntryDao.getActive();
    expect(entries.single.body, 'a boat made of glass sailing over the city');

    await unmountApp(tester);
  });

  testWidgets('dictation appends after existing text with one space, and '
      'stopping commits the live partial', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Night storm.');
    await tester.tap(find.byTooltip('Dictate dream'));
    await tester.pumpAndSettle();

    recognizer.emit('the sea was upside down', isFinal: true);
    await tester.pump();
    expect(editorText(tester), 'Night storm. the sea was upside down');

    // Stop while a partial is still on screen: it is committed, not lost.
    recognizer.emit('and the rain fell upward');
    await tester.pump();
    await tester.tap(find.byTooltip('Stop dictation'));
    await tester.pumpAndSettle();
    expect(
      editorText(tester),
      'Night storm. the sea was upside down and the rain fell upward',
    );

    await unmountApp(tester);
  });

  testWidgets('permission denial shows a friendly message and never starts', (
    tester,
  ) async {
    recognizer.available = false;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dictate dream'));
    await tester.pumpAndSettle();

    expect(recognizer.initializeCalls, 1);
    expect(recognizer.startCalls, 0);
    expect(find.text('Listening… speak your dream'), findsNothing);
    expect(
      find.textContaining('Microphone access is needed to dictate your dream'),
      findsOneWidget,
    );

    // Drain the snackbar's display timer before teardown.
    await tester.pump(const Duration(seconds: 5));
    await unmountApp(tester);
  });

  testWidgets('an engine-ended session resets the listening state', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Dictate dream'));
    await tester.pumpAndSettle();
    expect(find.text('Listening… speak your dream'), findsOneWidget);

    recognizer.emit('half a sentence');
    await tester.pump();
    recognizer.endSession();
    await tester.pump();

    expect(find.text('Listening… speak your dream'), findsNothing);
    expect(find.byTooltip('Dictate dream'), findsOneWidget);
    // What was dictated stays in the field.
    expect(editorText(tester), 'half a sentence');

    await unmountApp(tester);
  });
}
