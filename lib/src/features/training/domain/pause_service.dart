import 'training_settings.dart';
import 'training_settings_store.dart';

/// Pauses and resumes the training program.
///
/// While paused, all training notifications (reality checks and dream
/// clues) are suppressed — but NOT the morning journal reminder, which
/// keeps firing so the journaling habit survives a training break.
class PauseService {
  PauseService(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TrainingSettingsStore _store;
  final DateTime Function() _clock;

  /// Pauses training for [days] starting now.
  Future<void> pauseFor(int days) async {
    final settings = await _store.load();
    await _store.save(
      settings.copyWith(pausedUntil: _clock().add(Duration(days: days))),
    );
  }

  /// Resumes training immediately.
  Future<void> resume() async {
    final settings = await _store.load();
    if (settings.pausedUntil != null) {
      await _store.save(settings.copyWith(pausedUntil: null));
    }
  }

  /// Whether training is paused at [now].
  static bool isPaused(TrainingSettings settings, DateTime now) {
    final until = settings.pausedUntil;
    return until != null && now.isBefore(until);
  }
}
