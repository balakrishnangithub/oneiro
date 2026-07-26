import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards a privacy invariant: the manifest must keep
/// `android:allowBackup="false"`. With backup enabled, Android silently
/// parks an unencrypted copy of the journal database in the user's
/// Google/Samsung account (and hands it to device-to-device transfers) —
/// a third plaintext copy outside the zero-knowledge model, where the only
/// sanctioned backup is the user's own encrypted vault (see README →
/// Privacy).
void main() {
  test('Android manifest disables Auto Backup and D2D transfer', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    expect(
      manifest.readAsStringSync(),
      contains('android:allowBackup="false"'),
      reason: 'journal data must never leave the device unencrypted',
    );
  });
}
