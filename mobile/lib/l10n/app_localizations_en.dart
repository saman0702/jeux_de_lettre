// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Letter Race';

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
  String get roomTypeDuel => 'Duel';

  @override
  String get roomTypeGroup => 'Group (up to 8)';

  @override
  String get visibility => 'Visibility';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get create => 'CREATE';

  @override
  String get roomCode => 'Room code';

  @override
  String get copyCode => 'Copy';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get shareInvite => 'Invite';

  @override
  String inviteMessage(String code) {
    return 'Join my Letter Race game! Code: $code';
  }

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
    return '$name disconnected';
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
  String get noticeBotsJoined => 'Nobody online: bots are joining you!';

  @override
  String get errorNotHost => 'Only the host can do that.';

  @override
  String get botTag => 'Bot';

  @override
  String hintTitle(String category, String letter) {
    return 'Hint: $category starting with $letter';
  }

  @override
  String get hintSubtitle => 'Only one of these words is right!';

  @override
  String get statusHintWrong => 'Wrong pick';

  @override
  String get statusAlreadyUsed => 'Already used in this world';

  @override
  String get hintedBadge => 'Hint';

  @override
  String get hintNoneLeft => 'No hints left this game.';

  @override
  String get hintUnavailable => 'No hint available here.';

  @override
  String get buyHintTitle => 'Extra hint';

  @override
  String buyHintMessage(int count) {
    return 'Buy one hint for $count coins?';
  }

  @override
  String buyHintConfirm(int count) {
    return '$count coins';
  }

  @override
  String get buyInfoTitle => 'Facts';

  @override
  String buyInfoMessage(int count) {
    return 'Unlock the facts for $count coins?';
  }

  @override
  String buyInfoConfirm(int count) {
    return '$count coins';
  }

  @override
  String buyInfoButton(int count) {
    return 'Facts · $count coins';
  }

  @override
  String get buyInfoFree => 'Facts';

  @override
  String get notOnlineForPurchase => 'Go online to spend coins.';

  @override
  String get offlineModeNotice => 'No connection: playing solo offline';

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

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageAuto => 'Auto';

  @override
  String suggestionExample(String answer) {
    return 'Possible answer: $answer';
  }

  @override
  String suggestionFoundBy(String name, String answer) {
    return '$name found: $answer';
  }

  @override
  String coinsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
      zero: '0 coins',
    );
    return '$_temp0';
  }

  @override
  String coinsGained(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coins',
      one: '1 coin',
    );
    return '+$_temp0';
  }

  @override
  String get roomKind => 'Room';

  @override
  String get roomKindClassic => 'Classic';

  @override
  String get roomKindBet => 'Bets';

  @override
  String get stake => 'Stake per player';

  @override
  String stakeShort(int count) {
    return 'Stake $count';
  }

  @override
  String potLabel(int count) {
    return 'Pot: $count';
  }

  @override
  String get betRules =>
      'Everyone bets the same amount. The winner takes it all; ties share the pot. No bots.';

  @override
  String yourCoins(int count) {
    return 'Your balance: $count';
  }

  @override
  String betWon(int count) {
    return 'You win $count coins!';
  }

  @override
  String betLost(int count) {
    return 'Stake lost: $count coins';
  }

  @override
  String get errorNotEnoughCoins => 'Not enough coins for this stake.';

  @override
  String get errorBotsNotAllowed => 'No bots in a betting room.';

  @override
  String get avatarTitle => 'My avatar';

  @override
  String get avatarCamera => 'CAMERA';

  @override
  String get avatarGallery => 'GALLERY';

  @override
  String get avatarPhotoInfo =>
      'Your photo is turned into a drawing before other players see it.';

  @override
  String get avatarCharacters => 'Characters';

  @override
  String get avatarUpdated => 'Avatar updated!';

  @override
  String get errorInvalidImage => 'This image could not be read.';

  @override
  String get errorFileTooLarge => 'Image too large.';

  @override
  String get reportTitle => 'Report this photo?';

  @override
  String reportMessage(String name) {
    return '$name\'s photo is removed after several reports.';
  }

  @override
  String get reportConfirm => 'REPORT';

  @override
  String get reportSent => 'Thanks, report sent.';

  @override
  String get musicCredits =>
      'Music by Kevin MacLeod (incompetech.com), licensed under Creative Commons BY 4.0: “Monkeys Spinning Monkeys”, “Fluffing a Duck”, “Carefree”, “Pixel Peeker Polka”, “Sneaky Snitch”, “Investigations”, “Run Amok”, “Funkorama”, “Itty Bitty 8 Bit”, “Bit Quest”.';

  @override
  String get shopTitle => 'Shop';

  @override
  String get shopCoinsLabel => 'coins';

  @override
  String shopBonus(int percent) {
    return '+$percent%';
  }

  @override
  String shopBought(int count) {
    return '+$count coins, thank you!';
  }

  @override
  String get shopPending =>
      'Payment pending: your coins will arrive once it is confirmed.';

  @override
  String get shopInvalid => 'This purchase could not be validated.';

  @override
  String get shopStoreError => 'The purchase did not go through.';

  @override
  String get shopRetryLater =>
      'Purchase received: your coins will be added as soon as the server is reachable.';

  @override
  String get shopUnavailable =>
      'The shop is not available on this device right now.';

  @override
  String get shopLegal =>
      'Payment secured by Google Play or the App Store. Coins have no monetary value: they cannot be refunded, exchanged or converted into money.';

  @override
  String get avatarPhotoNeedsConnection =>
      'Go online to use a photo: it is turned into a drawing on the server.';

  @override
  String get avatarPickFailed =>
      'Could not open the camera or gallery. Check the app permissions.';

  @override
  String get avatarSavedOffline =>
      'Avatar chosen! It will be shared as soon as you are online.';

  @override
  String get credits => 'Credits';

  @override
  String levelUp(int level) {
    return 'LEVEL $level!';
  }

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String levelProgress(int xp, int needed) {
    return '$xp / $needed points to the next level';
  }

  @override
  String goalMinimum(int points) {
    return 'Min. $points pts';
  }

  @override
  String goalProgress(int score, int target) {
    return '$score / $target pts';
  }

  @override
  String challengePassed(int points) {
    return '$points PTS MINIMUM: PASSED!';
  }

  @override
  String challengeEliminated(int points) {
    return 'ELIMINATED! You needed $points pts';
  }

  @override
  String careerProgressBanner(int score, int target) {
    return 'Goal: $score / $target pts';
  }

  @override
  String careerWon(int level) {
    return 'Level $level cleared!';
  }

  @override
  String careerLost(int level) {
    return 'Level $level failed';
  }

  @override
  String careerMessage(int target, int score) {
    return 'Goal $target pts · you scored $score pts';
  }

  @override
  String careerStarsInfo(int one, int two, int three) {
    return 'Stars at $one, $two and $three pts';
  }

  @override
  String get nextLevel => 'NEXT LEVEL';

  @override
  String get replayLevel => 'REPLAY LEVEL';

  @override
  String get levelsMap => 'LEVEL MAP';

  @override
  String get eliminationChampion => 'Champion!';

  @override
  String get eliminationOut => 'Eliminated!';

  @override
  String eliminationMessage(int rounds, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds rounds',
      one: '1 round',
    );
    return 'You lasted $_temp0 out of $total';
  }

  @override
  String eliminationRecord(int rounds) {
    return 'Best: $rounds rounds';
  }

  @override
  String eliminationNewRecord(int rounds) {
    return 'New record: $rounds rounds!';
  }

  @override
  String get careerTitle => 'Career';

  @override
  String get careerRulesIntro =>
      '60 levels of 5 rounds, in 4 worlds of 15. One star opens the next level.';

  @override
  String get careerRulesFromConfirmed =>
      'In the Beginner world, the categories increase: City and Country, then Animal, then Fruit. From the Confirmed world on, first names are added. After that, the letters get harder and the score goal climbs.';

  @override
  String get careerRulesStars =>
      '1 star at the goal, then 2 and 3 stars as you get closer to a perfect score.';

  @override
  String get careerRulesBeginner =>
      'Easy letters, 60 then 45 then 30 seconds. City and Country, then Animal, then Fruit.';

  @override
  String get careerRulesConfirmed =>
      'Normal letters. The four categories, then a girl\'s name too.';

  @override
  String get careerRulesExpert =>
      'Every letter, including the rare ones. A boy\'s name is added too.';

  @override
  String get careerRulesMaster =>
      'Same six categories, higher score goals. Finding new words gets harder.';

  @override
  String get careerRulesReuse =>
      'In the same world, a word you already got right cannot be reused when that letter comes back.';

  @override
  String get gotIt => 'GOT IT';

  @override
  String get worldBeginner => 'Beginner';

  @override
  String get worldConfirmed => 'Confirmed';

  @override
  String get worldExpert => 'Expert';

  @override
  String get worldMaster => 'Master';

  @override
  String levelTitle(int level) {
    return 'Level $level';
  }

  @override
  String levelGoal(int target) {
    return 'Goal: $target points';
  }

  @override
  String get play => 'PLAY';

  @override
  String get modeCareer => 'Career';

  @override
  String get modeElimination => 'Knockout';

  @override
  String get modeFreeSolo => 'Free solo';

  @override
  String get eliminationRulesTitle => 'Rules';

  @override
  String eliminationRules(int rounds) {
    return 'All categories, 30 seconds per round. Score at least the minimum each round or you are out. Survive all $rounds rounds to become champion!';
  }

  @override
  String roundsRange(int from, int to) {
    return 'Rounds $from to $to';
  }

  @override
  String get eliminationBestTitle => 'Your best';

  @override
  String get eliminationNoRecord => 'No record yet';

  @override
  String get roomFormat => 'Format';

  @override
  String get formatRounds => 'Rounds';

  @override
  String get formatElimination => 'Knockout';

  @override
  String get formatRoundsHelp => 'Every round is played: the best total wins.';

  @override
  String get formatEliminationHelp =>
      'Each round, the lowest score is knocked out. The last one standing wins.';

  @override
  String get youAreEliminated => 'You are out: watch the end of the game!';

  @override
  String get youAreOut => 'You are out!';

  @override
  String playerIsOut(String name) {
    return '$name is out!';
  }

  @override
  String get categoryFemaleName => 'Girl\'s name';

  @override
  String get categoryMaleName => 'Boy\'s name';

  @override
  String manyCategoriesHint(int count) {
    return '$count categories or more: at least 45 seconds per round.';
  }

  @override
  String get preparingGame => 'Getting the game ready…';

  @override
  String get playAlone => 'PLAY ALONE';

  @override
  String get withFriends => 'With friends';

  @override
  String get withFriendsHelp =>
      'A room opens right away, with a code to share just like any other room. The lowest score each round is knocked out.';

  @override
  String get inviteFriends => 'INVITE FRIENDS';

  @override
  String get looksTitle => 'Style shop';

  @override
  String get looksSubtitle => 'Try a look, then buy it with your coins.';

  @override
  String get looksPreview => 'Your preview';

  @override
  String get looksPacks => 'Packs';

  @override
  String get looksHair => 'Hair';

  @override
  String get looksHat => 'Hats';

  @override
  String get looksFrame => 'Frames';

  @override
  String get looksName => 'Names';

  @override
  String get looksTiles => 'Tiles';

  @override
  String get looksVictory => 'Victory';

  @override
  String get looksPacksHint => 'Matching styles cheaper as a bundle.';

  @override
  String get looksHairHint =>
      'Swap hairstyles without changing your character.';

  @override
  String get looksHatHint => 'Crowns, caps and wizard hats.';

  @override
  String get looksFrameHint => 'Rings, ornaments, flames or stars.';

  @override
  String get looksNameHint => 'Color, gradient, outline or badge by your name.';

  @override
  String get looksTilesHint => 'Colors and patterns on letter tiles.';

  @override
  String get looksVictoryHint => 'Confetti, stars, bubbles or letter rain.';

  @override
  String get looksHairSpiky => 'Spiky';

  @override
  String get looksHairBob => 'Pink bob';

  @override
  String get looksHairCurly => 'Blue curls';

  @override
  String get looksHairBun => 'Gold bun';

  @override
  String get looksHatCrown => 'Crown';

  @override
  String get looksHatCap => 'Cap';

  @override
  String get looksHatWizard => 'Wizard hat';

  @override
  String get looksHatParty => 'Party';

  @override
  String get looksFrameOrnament => 'Ornament';

  @override
  String get looksFrameFlames => 'Flames';

  @override
  String get looksFrameStars => 'Stars';

  @override
  String get looksNameGradient => 'Gradient';

  @override
  String get looksNameOutline => 'Outline';

  @override
  String get looksNameBadge => 'Badge';

  @override
  String get looksTilesStripes => 'Stripes';

  @override
  String get looksTilesDots => 'Dots';

  @override
  String get looksTilesMetal => 'Metal';

  @override
  String get looksVictoryStars => 'Stars';

  @override
  String get looksVictoryBubbles => 'Bubbles';

  @override
  String get looksVictoryLetters => 'Letters';

  @override
  String get looksPackOcean => 'Ocean pack';

  @override
  String get looksPackCandy => 'Candy pack';

  @override
  String get looksPackRoyal => 'Royal pack';

  @override
  String looksPackContents(int count) {
    return '$count styles';
  }

  @override
  String get looksOwned => 'OWNED';

  @override
  String get looksEquip => 'EQUIP';

  @override
  String get looksEquipped => 'EQUIPPED';

  @override
  String looksPrice(int count) {
    return '$count coins';
  }

  @override
  String get looksNotEnough => 'Not enough coins.';

  @override
  String get looksGold => 'Gold';

  @override
  String get looksPink => 'Pink';

  @override
  String get looksCyan => 'Cyan';

  @override
  String get looksViolet => 'Violet';

  @override
  String get looksOrange => 'Orange';

  @override
  String get looksMint => 'Mint';
}
