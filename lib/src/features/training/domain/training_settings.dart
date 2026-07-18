/// Value types for the lucid-dreaming training engine.
///
/// Pure Dart: no Flutter, no plugins, so the whole training domain is unit
/// testable on the host. Times of day are stored as minutes-from-midnight
/// (0–1439) to keep this layer free of Flutter's [TimeOfDay].
library;

/// Totem sounds bundled with the app for night-time dream clues.
enum TotemSound {
  chime('totem_chime.wav'),
  bell('totem_bell.wav'),
  drop('totem_drop.wav');

  const TotemSound(this.fileName);

  /// File name under `assets/audio/`.
  final String fileName;

  /// Relative path handed to the audio player (`audioplayers` resolves it
  /// against the `assets/` prefix).
  String get assetPath => 'audio/$fileName';

  static TotemSound fromName(String? name) => TotemSound.values.firstWhere(
    (s) => s.name == name,
    orElse: () => TotemSound.chime,
  );
}

/// Sentinel for [TrainingSettings.copyWith] so callers can distinguish
/// "leave unchanged" from "set to null" for [TrainingSettings.pausedUntil].
const Object _unset = Object();

/// All user-tunable knobs of the training engine, plus the pause state.
///
/// Defaults mirror a gentle starter program: three reality checks spread
/// over the waking day, a 05:00 journal prompt, and dream clues off until
/// the user opts in.
class TrainingSettings {
  const TrainingSettings({
    this.realityChecksEnabled = true,
    this.checksPerDay = 3,
    this.dayStartMinutes = 8 * 60,
    this.dayEndMinutes = 22 * 60,
    this.dayAlertSound = true,
    this.dreamCluesEnabled = false,
    this.cluesPerNight = 10,
    this.nightStartMinutes = 2 * 60 + 30,
    this.nightEndMinutes = 7 * 60 + 30,
    this.totemSound = TotemSound.chime,
    this.clueVolume = 0.45,
    this.morningReminderEnabled = true,
    this.morningMinutes = 5 * 60,
    this.pausedUntil,
  });

  static const int minChecksPerDay = 1;
  static const int maxChecksPerDay = 10;
  static const int minCluesPerNight = 1;
  static const int maxCluesPerNight = 20;

  /// Whether daytime reality-check reminders fire.
  final bool realityChecksEnabled;

  /// Reality checks per day, [minChecksPerDay]–[maxChecksPerDay].
  final int checksPerDay;

  /// Start of the daytime window, minutes from midnight.
  final int dayStartMinutes;

  /// End of the daytime window, minutes from midnight.
  final int dayEndMinutes;

  /// Whether reality-check alerts make a sound.
  final bool dayAlertSound;

  /// Whether night-time dream clues (totem sounds) are scheduled.
  final bool dreamCluesEnabled;

  /// Dream clues per night, [minCluesPerNight]–[maxCluesPerNight].
  final int cluesPerNight;

  /// Start of the night window, minutes from midnight. May be later than
  /// [nightEndMinutes], in which case the window crosses midnight.
  final int nightStartMinutes;

  /// End of the night window, minutes from midnight.
  final int nightEndMinutes;

  /// Which totem sound plays as the dream clue.
  final TotemSound totemSound;

  /// Playback volume for dream clues, 0.0–1.0.
  final double clueVolume;

  /// Whether the silent morning journal reminder fires.
  final bool morningReminderEnabled;

  /// Time of the morning reminder, minutes from midnight.
  final int morningMinutes;

  /// Training is paused while `now` is before this instant. `null` means
  /// training is active. The morning journal reminder is never paused.
  final DateTime? pausedUntil;

  TrainingSettings copyWith({
    bool? realityChecksEnabled,
    int? checksPerDay,
    int? dayStartMinutes,
    int? dayEndMinutes,
    bool? dayAlertSound,
    bool? dreamCluesEnabled,
    int? cluesPerNight,
    int? nightStartMinutes,
    int? nightEndMinutes,
    TotemSound? totemSound,
    double? clueVolume,
    bool? morningReminderEnabled,
    int? morningMinutes,
    Object? pausedUntil = _unset,
  }) {
    return TrainingSettings(
      realityChecksEnabled: realityChecksEnabled ?? this.realityChecksEnabled,
      checksPerDay: checksPerDay ?? this.checksPerDay,
      dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
      dayEndMinutes: dayEndMinutes ?? this.dayEndMinutes,
      dayAlertSound: dayAlertSound ?? this.dayAlertSound,
      dreamCluesEnabled: dreamCluesEnabled ?? this.dreamCluesEnabled,
      cluesPerNight: cluesPerNight ?? this.cluesPerNight,
      nightStartMinutes: nightStartMinutes ?? this.nightStartMinutes,
      nightEndMinutes: nightEndMinutes ?? this.nightEndMinutes,
      totemSound: totemSound ?? this.totemSound,
      clueVolume: clueVolume ?? this.clueVolume,
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      morningMinutes: morningMinutes ?? this.morningMinutes,
      pausedUntil: identical(pausedUntil, _unset)
          ? this.pausedUntil
          : pausedUntil as DateTime?,
    );
  }

  /// Returns a copy with every value clamped into its legal range.
  TrainingSettings normalized() => copyWith(
    checksPerDay: checksPerDay.clamp(minChecksPerDay, maxChecksPerDay),
    cluesPerNight: cluesPerNight.clamp(minCluesPerNight, maxCluesPerNight),
    clueVolume: clueVolume.clamp(0.0, 1.0),
  );

  @override
  bool operator ==(Object other) =>
      other is TrainingSettings &&
      other.realityChecksEnabled == realityChecksEnabled &&
      other.checksPerDay == checksPerDay &&
      other.dayStartMinutes == dayStartMinutes &&
      other.dayEndMinutes == dayEndMinutes &&
      other.dayAlertSound == dayAlertSound &&
      other.dreamCluesEnabled == dreamCluesEnabled &&
      other.cluesPerNight == cluesPerNight &&
      other.nightStartMinutes == nightStartMinutes &&
      other.nightEndMinutes == nightEndMinutes &&
      other.totemSound == totemSound &&
      other.clueVolume == clueVolume &&
      other.morningReminderEnabled == morningReminderEnabled &&
      other.morningMinutes == morningMinutes &&
      other.pausedUntil == pausedUntil;

  @override
  int get hashCode => Object.hashAll([
    realityChecksEnabled,
    checksPerDay,
    dayStartMinutes,
    dayEndMinutes,
    dayAlertSound,
    dreamCluesEnabled,
    cluesPerNight,
    nightStartMinutes,
    nightEndMinutes,
    totemSound,
    clueVolume,
    morningReminderEnabled,
    morningMinutes,
    pausedUntil,
  ]);
}

/// Formats minutes-from-midnight as `HH:mm` (24-hour, zero-padded).
String formatMinutesOfDay(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
