// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Letter Battle';

  @override
  String get tagline => 'Une lettre. Quatre catégories. Le plus rapide gagne.';

  @override
  String get modeSolo => 'Solo';

  @override
  String get modeDuel => 'Duel';

  @override
  String get modeMultiplayer => 'Multijoueur';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get serverOnline => 'Serveur connecté';

  @override
  String get serverOffline => 'Serveur injoignable';

  @override
  String get serverChecking => 'Connexion au serveur…';

  @override
  String get categoryCity => 'Ville';

  @override
  String get categoryCountry => 'Pays';

  @override
  String get categoryAnimal => 'Animal';

  @override
  String get categoryFruit => 'Fruit';

  @override
  String get soloSetupTitle => 'Partie solo';

  @override
  String get rounds => 'Manches';

  @override
  String get roundDuration => 'Durée d\'une manche';

  @override
  String secondsShort(int seconds) {
    return '$seconds s';
  }

  @override
  String get categories => 'Catégories';

  @override
  String get selectOneCategory => 'Choisis au moins une catégorie';

  @override
  String get difficulty => 'Difficulté';

  @override
  String get difficultyEasy => 'Facile';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Difficile';

  @override
  String get startGame => 'JOUER';

  @override
  String get defaultNickname => 'Joueur';

  @override
  String roundProgress(int current, int total) {
    return 'Manche $current / $total';
  }

  @override
  String get letterLabel => 'LETTRE';

  @override
  String get finish => 'TERMINER';

  @override
  String get go => 'GO !';

  @override
  String get statusValid => 'Valide';

  @override
  String get statusEmpty => 'Pas de réponse';

  @override
  String get statusWrongLetter => 'Mauvaise lettre';

  @override
  String get statusNotFound => 'Réponse inconnue';

  @override
  String get statusLate => 'Temps écoulé';

  @override
  String pointsShort(int points) {
    return '$points pts';
  }

  @override
  String get roundScore => 'Score de la manche';

  @override
  String get totalScore => 'Total';

  @override
  String finishedIn(String seconds) {
    return 'Terminé en $seconds s';
  }

  @override
  String get nextRound => 'MANCHE SUIVANTE';

  @override
  String get seeResults => 'VOIR LE RÉSULTAT';

  @override
  String get gameOver => 'PARTIE TERMINÉE';

  @override
  String get playAgain => 'REJOUER';

  @override
  String get backHome => 'Accueil';

  @override
  String get errorNetwork => 'Connexion au serveur impossible.';

  @override
  String get errorGeneric => 'Une erreur est survenue.';

  @override
  String get retry => 'Réessayer';

  @override
  String get quitGameTitle => 'Quitter la partie ?';

  @override
  String get quitGameMessage => 'Ta progression sera perdue.';

  @override
  String get quit => 'Quitter';

  @override
  String get cancel => 'Annuler';

  @override
  String get comingSoonBadge => 'Bientôt';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSound => 'Effets sonores';

  @override
  String get settingsMusic => 'Musique';

  @override
  String get settingsVibration => 'Vibrations';

  @override
  String roundPoints(int points) {
    return '+$points';
  }

  @override
  String get gameOverGreat => 'Incroyable !';

  @override
  String get gameOverGood => 'Bien joué !';

  @override
  String get gameOverTry => 'Tu peux faire mieux !';
}
