import 'training_settings.dart';

/// Plays the totem sound used as a night-time dream clue.
///
/// Interface so the scheduler and UI never touch the audio plugin directly;
/// tests substitute a fake that only records calls.
abstract class CluePlayer {
  /// Plays [sound] once at [volume] (0.0–1.0).
  Future<void> play(TotemSound sound, double volume);
}
