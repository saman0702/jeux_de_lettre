import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

enum Haptic { light, medium, heavy }

/// Makes the phone vibrate. Android's "haptic feedback" depends on a system
/// touch setting that is often off, so real vibrations are used instead.
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

  // (milliseconds, amplitude 1-255)
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

/// Records vibrations; used by tests.
class SilentVibrator implements Vibrator {
  final List<Haptic> vibrations = [];

  @override
  void vibrate(Haptic kind) => vibrations.add(kind);
}
