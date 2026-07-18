import 'package:oneiro/src/features/speech/domain/speech_recognizer.dart';

/// Scripted [SpeechRecognizer] for widget tests — mirrors the fake-plugin
/// pattern used by the training, backup and sync features.
class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({this.available = true});

  /// What [initialize] returns: false simulates permission denied.
  bool available;

  int initializeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;

  bool _listening = false;
  void Function(SpeechPhrase phrase)? _onPhrase;
  void Function()? _onSessionEnd;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return available;
  }

  @override
  Future<void> start({
    required void Function(SpeechPhrase phrase) onPhrase,
    void Function()? onSessionEnd,
  }) async {
    startCalls++;
    _listening = true;
    _onPhrase = onPhrase;
    _onSessionEnd = onSessionEnd;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _listening = false;
  }

  /// Simulates the engine delivering a phrase (partial by default).
  void emit(String words, {bool isFinal = false}) {
    _onPhrase?.call(SpeechPhrase(words, isFinal: isFinal));
  }

  /// Simulates the engine ending the session on its own (timeout/error).
  void endSession() {
    _listening = false;
    _onSessionEnd?.call();
  }
}
