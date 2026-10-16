import 'package:flutter/widgets.dart';

import '../audio/game_audio.dart';
import '../settings/app_settings.dart';
import '../voice/announcer.dart';
import 'vibrator.dart';

export 'vibrator.dart' show Haptic;

/// Sons, musique et vibrations, filtrés selon les réglages du joueur.
class GameFeedback {
  GameFeedback({
    required this.audio,
    required this.settings,
    Vibrator? vibrator,
    Announcer? announcer,
    this.ambientMotion = true,
  }) : vibrator = vibrator ?? SilentVibrator(),
       announcer = announcer ?? SilentAnnouncer() {
    settings.addListener(_syncMusic);
  }

  /// Aucun son ni animation de fond en boucle ; utilisé par les tests.
  factory GameFeedback.silent() => GameFeedback(
    audio: SilentGameAudio(),
    settings: AppSettings.inMemory(),
    ambientMotion: false,
  );

  final GameAudio audio;
  final AppSettings settings;
  final Vibrator vibrator;
  final Announcer announcer;

  /// Animations décoratives sans fin (fond animé...). Désactivées dans les
  /// tests pour que `pumpAndSettle` puisse se stabiliser.
  final bool ambientMotion;

  MusicMood? _mood;
  bool _musicQuiet = false;
  bool _appInForeground = true;

  void play(Sfx sfx) {
    if (settings.sound) audio.play(sfx);
  }

  void announce(String text, String languageCode) {
    if (settings.voice && settings.sound) announcer.say(text, languageCode);
  }

  void haptic(Haptic kind) {
    if (settings.vibration) vibrator.vibrate(kind);
  }

  /// Ambiance de l'écran affiché (null : pas de musique).
  MusicMood? get music => _mood;

  /// Change l'ambiance ; [quiet] baisse le volume pendant les manches.
  void setMusic(MusicMood? mood, {bool quiet = false}) {
    _mood = mood;
    _musicQuiet = quiet;
    _syncMusic();
  }

  set appInForeground(bool value) {
    _appInForeground = value;
    _syncMusic();
  }

  void _syncMusic() {
    final mood = _mood;
    if (mood != null && _appInForeground && settings.music) {
      audio.startMusic(mood, quiet: _musicQuiet);
    } else {
      audio.stopMusic();
    }
  }
}

class GameFeedbackScope extends InheritedWidget {
  const GameFeedbackScope({
    super.key,
    required this.feedback,
    required super.child,
  });

  final GameFeedback feedback;

  static GameFeedback of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GameFeedbackScope>()!.feedback;

  @override
  bool updateShouldNotify(GameFeedbackScope oldWidget) =>
      feedback != oldWidget.feedback;
}
