// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Letter Battle';

  @override
  String get tagline => 'One letter. Four categories. Fastest wins.';

  @override
  String get modeSolo => 'Solo';

  @override
  String get modeDuel => 'Duel';

  @override
  String get modeMultiplayer => 'Multiplayer';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get serverOnline => 'Server connected';

  @override
  String get serverOffline => 'Server unreachable';

  @override
  String get serverChecking => 'Connecting to server…';

  @override
  String get categoryCity => 'City';

  @override
  String get categoryCountry => 'Country';

  @override
  String get categoryAnimal => 'Animal';

  @override
  String get categoryFruit => 'Fruit';

  @override
  String get soloSetupTitle => 'Solo game';

  @override
  String get rounds => 'Rounds';

  @override
  String get roundDuration => 'Round duration';

  @override
  String secondsShort(int seconds) {
    return '${seconds}s';
  }

  @override
  String get categories => 'Categories';

  @override
  String get selectOneCategory => 'Pick at least one category';

  @override
  String get difficulty => 'Difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyNormal => 'Normal';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get startGame => 'PLAY';

  @override
  String get defaultNickname => 'Player';

  @override
  String roundProgress(int current, int total) {
    return 'Round $current / $total';
  }

  @override
  String get letterLabel => 'LETTER';

  @override
  String get finish => 'FINISH';

  @override
  String get go => 'GO!';

  @override
  String get statusValid => 'Valid';

  @override
  String get statusEmpty => 'No answer';

  @override
  String get statusWrongLetter => 'Wrong letter';

  @override
  String get statusNotFound => 'Unknown answer';

  @override
  String get statusLate => 'Time\'s up';

  @override
  String pointsShort(int points) {
    return '$points pts';
  }

  @override
  String get roundScore => 'Round score';

  @override
  String get totalScore => 'Total';

  @override
  String finishedIn(String seconds) {
    return 'Finished in ${seconds}s';
  }

  @override
  String get nextRound => 'NEXT ROUND';

  @override
  String get seeResults => 'SEE RESULTS';

  @override
  String get gameOver => 'GAME OVER';

  @override
  String get playAgain => 'PLAY AGAIN';

  @override
  String get backHome => 'Home';

  @override
  String get errorNetwork => 'Cannot reach the server.';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get retry => 'Retry';

  @override
  String get quitGameTitle => 'Quit the game?';

  @override
  String get quitGameMessage => 'Your progress will be lost.';

  @override
  String get quit => 'Quit';

  @override
  String get cancel => 'Cancel';

  @override
  String get comingSoonBadge => 'Soon';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSound => 'Sound effects';

  @override
  String get settingsMusic => 'Music';

  @override
  String get settingsVibration => 'Vibrations';

  @override
  String roundPoints(int points) {
    return '+$points';
  }

  @override
  String get gameOverGreat => 'Amazing!';

  @override
  String get gameOverGood => 'Well played!';

  @override
  String get gameOverTry => 'You can do better!';
}
