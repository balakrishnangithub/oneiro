/// One recognized chunk of dictation.
class SpeechPhrase {
  const SpeechPhrase(this.words, {required this.isFinal});

  /// The words recognized so far in the current utterance.
  final String words;

  /// True when the recognizer committed this utterance (as opposed to a live
  /// partial result that may still change).
  final bool isFinal;
}

/// Thin seam over the device speech recognizer, so every plugin detail stays
/// out of the dream editor and widget tests can substitute a fake.
///
/// Typical flow: [initialize] once (this is where microphone permission is
/// requested; false = unavailable or denied), then [start] to begin
/// continuous dictation and [stop] to end it.
abstract class SpeechRecognizer {
  /// Whether a dictation session is currently running.
  bool get isListening;

  /// Prepares the engine and requests the microphone permission.
  ///
  /// Returns false when speech recognition is unavailable on this device or
  /// the user denied the permission — the UI should explain that instead of
  /// failing silently.
  Future<bool> initialize();

  /// Starts a dictation session. [onPhrase] delivers partial and final
  /// phrases; [onSessionEnd] fires if the session stops on its own (engine
  /// timeout or error), so the UI can reset its listening state.
  Future<void> start({
    required void Function(SpeechPhrase phrase) onPhrase,
    void Function()? onSessionEnd,
  });

  /// Ends the session gracefully (a final phrase may still be delivered).
  Future<void> stop();
}
