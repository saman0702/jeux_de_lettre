import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks short announcements (round winner, encouragement).
abstract class Announcer {
  void say(String text, String languageCode);
  void stop();
}

/// The phone's text-to-speech voice; works offline once the language is installed.
class DeviceAnnouncer implements Announcer {
  final FlutterTts _tts = FlutterTts();
  String? _language;

  static const _locales = {'fr': 'fr-FR', 'en': 'en-US'};

  @override
  Future<void> say(String text, String languageCode) async {
    try {
      final locale = _locales[languageCode] ?? 'fr-FR';
      if (_language != locale) {
        await _tts.setLanguage(locale);
        // A lively game-show voice: a bit faster and higher than usual.
        await _tts.setSpeechRate(0.52);
        await _tts.setPitch(1.12);
        _language = locale;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (error) {
      debugPrint('Voice unavailable: $error');
    }
  }

  @override
  void stop() {
    _tts.stop().catchError((_) {});
  }
}

/// Records what would be said; used by tests.
class SilentAnnouncer implements Announcer {
  final List<String> said = [];

  @override
  void say(String text, String languageCode) => said.add(text);

  @override
  void stop() {}
}
