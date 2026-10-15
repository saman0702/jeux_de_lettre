import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  tap,
  countdown,
  go,
  tick,
  reveal,
  valid,
  invalid,
  points,
  victory,
  key,
  erase,
  match,
  finish,
  hintOpen,
}

/// Asset base name; some effects have variants (key_1, key_2...) played in turn.
const _sfxFiles = {Sfx.hintOpen: 'hint_open'};
const _sfxVariants = {
  Sfx.key: 3,
  Sfx.go: 3,
  Sfx.valid: 3,
  Sfx.invalid: 2,
  Sfx.points: 2,
  Sfx.victory: 2,
};

/// A random index in [0, count) different from [last] when there is a choice,
/// so a sound or tune never plays twice in a row.
int pickOtherIndex(Random random, int count, int? last) {
  if (count <= 1) return 0;
  final pick = random.nextInt(count - 1);
  return last == null || pick < last ? pick : pick + 1;
}

/// Menu tunes; a different one starts each time the menu music comes back.
const _musicTracks = ['menu_1.wav', 'menu_2.wav', 'menu_3.wav'];

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

  final Map<Sfx, List<AudioPool>> _pools = {};
  final Map<Sfx, int> _lastVariant = {};
  final _random = Random();
  final AudioPlayer _music = AudioPlayer();
  bool _musicWanted = false;
  int _track = -1;

  int _pickOther(int count, int? last) => pickOtherIndex(_random, count, last);

  static Future<GameAudio> create() async {
    final audio = AudioplayersGameAudio._();
    try {
      await AudioPlayer.global.setAudioContext(_context);
      for (final sfx in Sfx.values) {
        final base = _sfxFiles[sfx] ?? sfx.name;
        final variants = _sfxVariants[sfx];
        final files = variants == null
            ? ['$base.wav']
            : [for (var i = 1; i <= variants; i++) '${base}_$i.wav'];
        audio._pools[sfx] = [
          for (final file in files)
            await AudioPool.create(
              source: AssetSource('sounds/$file'),
              maxPlayers: 3,
              audioContext: _context,
            ),
        ];
      }
      await audio._music.setAudioContext(_context);
      await audio._music.setReleaseMode(ReleaseMode.loop);
      await audio._music.setVolume(_musicVolume);
    } catch (error) {
      debugPrint('Audio unavailable: $error');
      return SilentGameAudio();
    }
    return audio;
  }

  @override
  void play(Sfx sfx) {
    final pools = _pools[sfx];
    if (pools == null || pools.isEmpty) return;
    final index = _pickOther(pools.length, _lastVariant[sfx]);
    _lastVariant[sfx] = index;
    pools[index].start();
  }

  @override
  void startMusic() {
    if (_musicWanted) return;
    _musicWanted = true;
    _track = _pickOther(_musicTracks.length, _track < 0 ? null : _track);
    _playTrack(_track);
  }

  Future<void> _playTrack(int track) async {
    try {
      await _music.setSource(AssetSource('sounds/${_musicTracks[track]}'));
      // The menu may have been left while the tune was loading.
      if (_musicWanted && _track == track) await _music.resume();
    } catch (error) {
      debugPrint('Music unavailable: $error');
    }
  }

  @override
  void stopMusic() {
    if (!_musicWanted) return;
    _musicWanted = false;
    _music.pause();
  }
}
