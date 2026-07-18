import 'training_settings.dart';

/// Minimal persistence contract the training domain depends on.
///
/// The concrete implementation lives in the data layer
/// (`DriftSettingsRepository`); depending on this abstraction keeps the
/// domain pure and lets tests substitute in-memory fakes.
abstract class TrainingSettingsStore {
  Future<TrainingSettings> load();

  Future<void> save(TrainingSettings settings);
}
