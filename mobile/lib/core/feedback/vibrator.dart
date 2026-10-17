import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

enum Haptic { light, medium, heavy }

/// Fait vibrer le téléphone. Le « retour haptique » d'Android dépend d'un
/// réglage système souvent désactivé : on utilise donc de vraies vibrations.
abstract class Vibrator {
  void vibrate(Haptic kind);
}

class DeviceVibrator implements Vibrator {
  DeviceVibrator._(this._available, this._amplitude);

  static Future<Vibrator> create() async {
    try {
      final available = await Vibration.hasVibrator();
      final amplitude = available && await Vibration.hasAmplitudeControl();
      return DeviceVibrator._(available, amplitude);
    } catch (_) {
      return DeviceVibrator._(false, false);
    }
  }

  final bool _available;
  final bool _amplitude;

  // (millisecondes, amplitude 1-255)
  static const _patterns = {
    Haptic.light: (12, 70),
    Haptic.medium: (28, 150),
    Haptic.heavy: (60, 255),
  };

  @override
  void vibrate(Haptic kind) {
    if (!_available) {
      _fallback(kind);
      return;
    }
    final (duration, amplitude) = _patterns[kind]!;
    Vibration.vibrate(
      duration: duration,
      amplitude: _amplitude ? amplitude : -1,
    ).catchError((_) => _fallback(kind));
  }

  static void _fallback(Haptic kind) {
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

/// Enregistre les vibrations ; utilisé par les tests.
class SilentVibrator implements Vibrator {
  final List<Haptic> vibrations = [];

  @override
  void vibrate(Haptic kind) => vibrations.add(kind);
}
