import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../audio/game_audio.dart';
import '../settings/app_settings.dart';

enum Haptic { light, medium, heavy }

/// Sound, music and vibrations, filtered by the player's settings.
class GameFeedback {
  GameFeedback({
    required this.audio,
    required this.settings,
    this.ambientMotion = true,
  }) {
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

  /// Endless decorative animations (floating letters...). Disabled in tests so
  /// `pumpAndSettle` can settle.
  final bool ambientMotion;

  bool _musicWanted = false;
  bool _appInForeground = true;

  void play(Sfx sfx) {
    if (settings.sound) audio.play(sfx);
  }

  void haptic(Haptic kind) {
    if (!settings.vibration) return;
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
    }
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
