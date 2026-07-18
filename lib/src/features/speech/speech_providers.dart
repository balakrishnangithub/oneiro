import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/stt_speech_recognizer.dart';
import 'domain/speech_recognizer.dart';

/// The device speech recognizer used by the dream editor. Overridden in
/// tests with a fake — the plugin is never exercised on the host.
final speechRecognizerProvider = Provider<SpeechRecognizer>(
  (ref) => SttSpeechRecognizer(),
);
