import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { tap, countdown, go, tick, reveal, valid, invalid, points, victory }

/// Plays sound effects and the menu music.
abstract class GameAudio {
  void play(Sfx sfx);
  void startMusic();
  void stopMusic();
}

/// Used in tests and whenever audio cannot be initialised.
class SilentGameAudio implements GameAudio {
  final List<Sfx> played = [];
  bool musicPlaying = false;

  @override
  void play(Sfx sfx) => played.add(sfx);

  @override
  void startMusic() => musicPlaying = true;

  @override
  void stopMusic() => musicPlaying = false;
}

class AudioplayersGameAudio implements GameAudio {
  AudioplayersGameAudio._();

  static const _musicVolume = 0.45;

  // Mix with other apps' audio and between our own players, so a sound
  // effect never pauses the music.
  static final _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  final Map<Sfx, AudioPool> _pools = {};
  final AudioPlayer _music = AudioPlayer();
  bool _musicWanted = false;

  static Future<GameAudio> create() async {
    final audio = AudioplayersGameAudio._();
    try {
      await AudioPlayer.global.setAudioContext(_context);
      for (final sfx in Sfx.values) {
        audio._pools[sfx] = await AudioPool.create(
          source: AssetSource('sounds/${sfx.name}.wav'),
          maxPlayers: 3,
          audioContext: _context,
        );
      }
      await audio._music.setAudioContext(_context);
      await audio._music.setReleaseMode(ReleaseMode.loop);
      await audio._music.setVolume(_musicVolume);
      await audio._music.setSource(AssetSource('sounds/menu_music.wav'));
    } catch (error) {
      debugPrint('Audio unavailable: $error');
      return SilentGameAudio();
    }
    return audio;
  }

  @override
  void play(Sfx sfx) => _pools[sfx]?.start();

  @override
  void startMusic() {
    if (_musicWanted) return;
    _musicWanted = true;
    _music.resume();
  }

  @override
  void stopMusic() {
    if (!_musicWanted) return;
    _musicWanted = false;
    _music.pause();
  }
}
