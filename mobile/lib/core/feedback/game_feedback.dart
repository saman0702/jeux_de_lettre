import 'package:flutter/widgets.dart';

import '../audio/game_audio.dart';
import '../settings/app_settings.dart';
import '../voice/announcer.dart';
import 'vibrator.dart';

export 'vibrator.dart' show Haptic;

/// Sound, music and vibrations, filtered by the player's settings.
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

  /// No sound and no looping background animation; used by tests.
  factory GameFeedback.silent() => GameFeedback(
    audio: SilentGameAudio(),
    settings: AppSettings.inMemory(),
    ambientMotion: false,
  );

  final GameAudio audio;
  final AppSettings settings;
  final Vibrator vibrator;
  final Announcer announcer;

  /// Endless decorative animations (floating letters...). Disabled in tests so
  /// `pumpAndSettle` can settle.
  final bool ambientMotion;

  bool _musicWanted = false;
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

  /// Menus want music; the game screen does not.
  set musicWanted(bool value) {
    _musicWanted = value;
    _syncMusic();
  }

  set appInForeground(bool value) {
    _appInForeground = value;
    _syncMusic();
  }

  void _syncMusic() {
    if (_musicWanted && _appInForeground && settings.music) {
      audio.startMusic();
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
