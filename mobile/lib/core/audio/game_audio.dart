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

/// Nom de base du fichier ; certains effets ont des variantes (key_1, key_2...)
/// jouées à tour de rôle.
const _sfxFiles = {Sfx.hintOpen: 'hint_open'};
const _sfxVariants = {
  Sfx.key: 3,
  Sfx.go: 3,
  Sfx.valid: 3,
  Sfx.invalid: 2,
  Sfx.points: 2,
  Sfx.victory: 2,
};

/// Un index au hasard dans [0, count) différent de [last] quand il y a le
/// choix, pour qu'un son ou une musique ne passe jamais deux fois de suite.
int pickOtherIndex(Random random, int count, int? last) {
  if (count <= 1) return 0;
  final pick = random.nextInt(count - 1);
  return last == null || pick < last ? pick : pick + 1;
}

/// Musiques de menu (Kevin MacLeod, CC BY 4.0, voir les crédits) : une autre
/// démarre à chaque retour au menu et quand un morceau se termine.
const musicTracks = [
  'music_monkeys.mp3',
  'music_duck.mp3',
  'music_carefree.mp3',
  'music_polka.mp3',
];

/// Joue les effets sonores et la musique du menu.
abstract class GameAudio {
  void play(Sfx sfx);
  void startMusic();
  void stopMusic();
}

/// Utilisé dans les tests et quand l'audio ne peut pas être initialisé.
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

  static const _musicVolume = 0.35;

  // Se mélange au son des autres applis et entre nos propres lecteurs, pour
  // qu'un effet sonore ne mette jamais la musique en pause.
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
      await audio._music.setReleaseMode(ReleaseMode.release);
      await audio._music.setVolume(_musicVolume);
      audio._music.onPlayerComplete.listen((_) => audio._nextTrack());
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
    _nextTrack();
  }

  void _nextTrack() {
    if (!_musicWanted) return;
    _track = _pickOther(musicTracks.length, _track < 0 ? null : _track);
    _playTrack(_track);
  }

  Future<void> _playTrack(int track) async {
    try {
      await _music.setSource(AssetSource('sounds/${musicTracks[track]}'));
      // Le menu a pu être quitté pendant le chargement de la musique.
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
