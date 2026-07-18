import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_recognizer.dart';

/// [SpeechRecognizer] backed by `package:speech_to_text`.
///
/// Android ends a listen session after a short pause, so continuous
/// dictation is emulated by re-listening whenever the engine reports
/// `done`/`notListening` while the user has not stopped the session. A
/// permanent error (or a failed re-listen) ends the session via
/// [SpeechRecognizer.start]'s `onSessionEnd`.
class SttSpeechRecognizer implements SpeechRecognizer {
  SttSpeechRecognizer([SpeechToText? engine])
    : _engine = engine ?? SpeechToText();

  final SpeechToText _engine;

  bool _initialized = false;

  /// True while the user wants dictation to keep going (survives engine
  /// restarts within one session).
  bool _active = false;
  void Function(SpeechPhrase phrase)? _onPhrase;
  void Function()? _onSessionEnd;

  @override
  bool get isListening => _active;

  @override
  Future<bool> initialize() async {
    _initialized = await _engine.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );
    return _initialized;
  }

  @override
  Future<void> start({
    required void Function(SpeechPhrase phrase) onPhrase,
    void Function()? onSessionEnd,
  }) async {
    if (!_initialized) {
      throw StateError('initialize() must succeed before start()');
    }
    _active = true;
    _onPhrase = onPhrase;
    _onSessionEnd = onSessionEnd;
    await _listen();
  }

  Future<void> _listen() {
    return _engine.listen(
      onResult: (result) => _onPhrase?.call(
        SpeechPhrase(result.recognizedWords, isFinal: result.finalResult),
      ),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        // Generous windows: dream dictation is meandering, and Android caps
        // them anyway — the restart logic in _handleStatus picks sessions
        // back up when the engine cuts them short.
        pauseFor: const Duration(seconds: 30),
        listenFor: const Duration(minutes: 5),
      ),
    );
  }

  void _handleStatus(String status) {
    if (!_active) return;
    if (status == 'done' || status == 'notListening') {
      // Engine ended the session (pause timeout); restart for continuity.
      unawaited(
        _listen().catchError((Object _) {
          _endSession();
          return null;
        }),
      );
    }
  }

  void _handleError(SpeechRecognitionError error) {
    // cancelOnError already cancelled the session; tell the UI.
    _endSession();
  }

  void _endSession() {
    if (!_active) return;
    _active = false;
    _onPhrase = null;
    _onSessionEnd?.call();
    _onSessionEnd = null;
  }

  @override
  Future<void> stop() async {
    _active = false;
    _onPhrase = null;
    _onSessionEnd = null;
    await _engine.stop();
  }
}
