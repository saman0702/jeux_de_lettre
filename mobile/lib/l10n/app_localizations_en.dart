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

  @override
  String get modeQuickMatch => 'Quick match';

  @override
  String get modeRooms => 'Rooms';

  @override
  String onlineCount(int count) {
    return '$count online';
  }

  @override
  String get offlineShort => 'Offline';

  @override
  String get nicknameTitle => 'Pick a nickname';

  @override
  String get nicknameHint => 'Your nickname';

  @override
  String get nicknameConfirm => 'LET\'S GO!';

  @override
  String get roomsTitle => 'Rooms';

  @override
  String get createRoom => 'CREATE A ROOM';

  @override
  String get joinWithCode => 'Join with a code';

  @override
  String get joinCodeTitle => 'Room code';

  @override
  String get join => 'Join';

  @override
  String get publicRoomsTitle => 'Open rooms';

  @override
  String get noPublicRooms => 'No open rooms right now. Create yours!';

  @override
  String roomOf(String name) {
    return '$name\'s room';
  }

  @override
  String roundsCount(int count) {
    return '$count rounds';
  }

  @override
  String playersCount(int count, int max) {
    return '$count/$max';
  }

  @override
  String get createRoomTitle => 'New room';

  @override
  String get roomType => 'Game type';

  @override
  String get roomTypeDuel => '⚔️ Duel';

  @override
  String get roomTypeGroup => '👥 Group (up to 8)';

  @override
  String get visibility => 'Visibility';

  @override
  String get visibilityPublic => '🌐 Public';

  @override
  String get visibilityPrivate => '🔒 Private';

  @override
  String get create => 'CREATE';

  @override
  String get roomCode => 'Room code';

  @override
  String get copyCode => 'Copy';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get waitingForPlayers => 'Waiting for players…';

  @override
  String get readyButton => 'I\'M READY!';

  @override
  String get notReadyButton => 'NOT YET';

  @override
  String get readyHint =>
      'The game starts when everyone is ready (2 players minimum).';

  @override
  String quickStartsIn(int seconds) {
    return 'Starting in ${seconds}s';
  }

  @override
  String get searchingPlayers => 'Looking for players…';

  @override
  String get hostBadge => 'Host';

  @override
  String get readyBadge => 'Ready';

  @override
  String get youBadge => 'You';

  @override
  String get answersSent => 'Answers sent!';

  @override
  String get waitingOthers => 'Waiting for the other players…';

  @override
  String get spectating => 'You\'ll play from the next round.';

  @override
  String get yourAnswers => 'Your answers';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String nextRoundIn(int seconds) {
    return 'Next round in ${seconds}s';
  }

  @override
  String get podiumTitle => 'PODIUM';

  @override
  String get leaveRoom => 'LEAVE';

  @override
  String get leaveRoomMessage => 'You are about to leave the room.';

  @override
  String noticeJoined(String name) {
    return '$name joined the room';
  }

  @override
  String noticeLeft(String name) {
    return '$name left the room';
  }

  @override
  String noticeDisconnected(String name) {
    return '⚠️ $name disconnected';
  }

  @override
  String noticeReconnected(String name) {
    return '$name is back';
  }

  @override
  String get connectionLost => 'Connection lost… reconnecting';

  @override
  String get errorRoomNotFound => 'Room not found.';

  @override
  String get errorRoomFull => 'This room is full.';

  @override
  String get errorGameInProgress => 'The game has already started.';

  @override
  String get opponents => 'Opponents';

  @override
  String get opponentsNone => 'None';

  @override
  String get botLevel => 'Bot level';

  @override
  String get addBot => 'Add a bot';

  @override
  String get noticeBotsJoined => 'Nobody online: bots are joining you 🤖';

  @override
  String get errorNotHost => 'Only the host can do that.';

  @override
  String get botTag => 'Bot';

  @override
  String hintTitle(String category, String letter) {
    return '💡 Hint: $category starting with $letter';
  }

  @override
  String get hintSubtitle => 'Only one of these words is right!';

  @override
  String get statusHintWrong => 'Wrong pick';

  @override
  String get hintedBadge => 'Hint';

  @override
  String get hintNoneLeft => 'No hints left this game.';

  @override
  String get hintUnavailable => 'No hint available here.';

  @override
  String get offlineModeNotice => '📴 No connection: playing solo offline';

  @override
  String get settingsGameKeyboard => 'Game keyboard';

  @override
  String get keyNext => 'Next';

  @override
  String get keySpace => 'space';

  @override
  String get settingsVoice => 'Announcer voice';

  @override
  String voiceYouWinRound1(String name) {
    return 'Well done $name, you win the round!';
  }

  @override
  String voiceYouWinRound2(String name) {
    return 'Excellent $name! Round won!';
  }

  @override
  String voiceOtherWinsRound1(String name) {
    return '$name wins the round!';
  }

  @override
  String voiceOtherWinsRound2(String name) {
    return 'This round goes to $name!';
  }

  @override
  String get voiceEncourage1 => 'Hang in there, you\'ll catch up!';

  @override
  String get voiceEncourage2 => 'Don\'t worry, the next one is yours!';

  @override
  String get voiceEncourage3 => 'Come on, don\'t give up!';

  @override
  String get voiceTie => 'It\'s a tie! Everything is still possible!';

  @override
  String get voiceNobodyScored => 'Nobody scored! Focus, here we go again!';

  @override
  String voiceSoloGreat(int points) {
    return 'Superb! $points points!';
  }

  @override
  String voiceSoloGood(int points) {
    return 'Well played, $points points!';
  }

  @override
  String get voiceSoloLow => 'Come on, you can do better next time!';

  @override
  String get voiceSoloZero => 'Ouch, no points! Take a breath, you can do it!';

  @override
  String voiceYouWinGame(String name) {
    return 'Victory! Well done $name, you win the game!';
  }

  @override
  String voiceOtherWinsGame(String name) {
    return '$name wins the game! Well played everyone. Rematch?';
  }

  @override
  String voiceSoloGameEnd(int points) {
    return 'Game over! $points points in total!';
  }

  @override
  String get dialogStay => 'STAY';

  @override
  String get roundLabel => 'ROUND';

  @override
  String get onlineLabel => 'ONLINE';
}
