import 'package:audioplayers/audioplayers.dart';

import '../domain/clue_player.dart';
import '../domain/training_settings.dart';

/// [CluePlayer] backed by the `audioplayers` plugin.
///
/// Used when a dream clue triggers while the app is in the foreground, and
/// for the totem preview button in Settings.
class DreamCluePlayer implements CluePlayer {
  DreamCluePlayer([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(TotemSound sound, double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
    await _player.play(AssetSource(sound.assetPath));
  }

  Future<void> dispose() => _player.dispose();
}
