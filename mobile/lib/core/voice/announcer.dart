import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Prononce de courtes annonces (gagnant de la manche, encouragements).
abstract class Announcer {
  void say(String text, String languageCode);
  void stop();
}

/// La voix de synthèse du téléphone ; fonctionne hors ligne une fois la langue
/// installée.
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
        // Une voix enjouée de jeu télé : un peu plus rapide et plus aiguë que
        // d'habitude.
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

/// Enregistre ce qui serait dit ; utilisé par les tests.
class SilentAnnouncer implements Announcer {
  final List<String> said = [];

  @override
  void say(String text, String languageCode) => said.add(text);

  @override
  void stop() {}
}
