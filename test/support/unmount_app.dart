import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unmounts the app under test and pumps one more frame.
///
/// Riverpod cancels drift's watched streams on dispose, and drift schedules a
/// zero-duration timer to release its stream cache. Without the extra pump,
/// `flutter_test` fails the test with "A Timer is still pending".
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // First pump lets the cancelled stream subscription finish closing; the
  // settle advances fake time so drift's zero-duration release timer fires.
  await tester.pump();
  await tester.pumpAndSettle();
}
