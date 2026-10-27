// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mind Race';

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
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get winnerPrize => 'Winner\'s prize';

  @override
  String get winnerPrizeHelp =>
      'You put up coins when creating the competition; only the winner takes them. Others pay nothing.';

  @override
  String get noPrize => 'No prize';

  @override
  String get prizeCustomHint => 'Custom amount';

  @override
  String prizePotLabel(int coins) {
    return 'Prize: $coins coins';
  }

  @override
  String prizeLost(int coins) {
    return 'Prize lost ($coins)';
  }

  @override
  String get playVsBot => 'PLAY VS A BOT';

  @override
  String get playVsBots => 'PLAY VS BOTS';

  @override
  String get eliminationBotDifficultyHelp =>
      'Bot level when you play against the computer.';

  @override
  String noticeLeftGame(String name) {
    return '$name left the game';
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
  String get confirm => 'OK';

  @override
  String get roomFormat => 'Format';

  @override
  String get formatRelay => 'Relay';

  @override
  String get formatRelayHelp =>
      'Each player only gets some of the categories (shared out). Team up… or exploit the gaps!';

  @override
  String get formatRoundsHelpLong =>
      'Everyone plays every round. Highest total score wins. Classic and clear.';

  @override
  String get formatEliminationHelpLong =>
      'After each round the lowest score is out (with 2 players: only on the last round). Last one standing wins.';

  @override
  String get roomTheme => 'Theme of the day';

  @override
  String get roomThemeHelp =>
      'Theme categories score double points. Pick geo, names or nature to spice things up.';

  @override
  String get visibilityHelp =>
      'Public: every online player is notified and can join with one tap, no code. Private: only people with the code can enter.';

  @override
  String get publicRoomLobbyHelp =>
      'Public room: visible to every online player. They can join without a code from Rooms.';

  @override
  String publicRoomInvite(String host) {
    return 'New public room by $host';
  }

  @override
  String get joinPublicRoom => 'JOIN';

  @override
  String get joinWithCodeHelp => 'For private rooms only';

  @override
  String get difficultyHelp =>
      'Easy = common letters. Hard = every letter, including K, W, X, Y, Z.';

  @override
  String get roomTypeHelp =>
      'Duel = 2 players. Group = up to 8. More players means more shared points.';

  @override
  String get durationHelp =>
      'Time to fill every category. More categories or strict spelling means a longer minimum.';

  @override
  String get themeNone => 'None';

  @override
  String get themeGeography => 'Geo (×2 cities & countries)';

  @override
  String get themeNames => 'Names (×2)';

  @override
  String get themeNature => 'Nature (×2 animals & fruits)';

  @override
  String freezeUse(int count) {
    return 'FREEZE ($count)';
  }

  @override
  String get freezeBuyTitle => 'Buy a Freeze';

  @override
  String freezeBuyHelp(int price) {
    return 'Lock an opponent for 10 seconds. Costs $price coins.\nYou get 1 free Freeze per game.';
  }

  @override
  String get freezeInfoHelp =>
      'During a round, freeze an opponent for 10 seconds so they can\'t submit. 1 free Freeze per game, then 15 coins to buy more.';

  @override
  String get freezePickTarget => 'Who to freeze?';

  @override
  String get freezeAlready => 'Already frozen';

  @override
  String get freezeYouAreFrozen => '❄ You\'re frozen! Hang on…';

  @override
  String get lightningTitle => 'Lightning!';

  @override
  String lightningHelp(String category, String letter, int seconds) {
    return '$category with $letter — ${seconds}s';
  }

  @override
  String get lightningInfoHelp =>
      'Between rounds: a 10-second quiz. The right answer gives +2 bonus points. Be quick!';

  @override
  String lightningHit(int points) {
    return 'Nice! +$points';
  }

  @override
  String get lightningMiss => 'Missed!';

  @override
  String get chatTitle => 'Room chat';

  @override
  String get chatHint => 'Type a message…';

  @override
  String get chatUnlockTitle => 'Unlock private messages';

  @override
  String chatUnlockHelp(int price) {
    return 'Write privately to any player in this room (nobody else can read you). Costs $price coins, once for this room.';
  }

  @override
  String chatUnlockButton(int price) {
    return 'PRIVATE · $price';
  }

  @override
  String get chatInfoHelp =>
      'The group chat is free and stays in the room, even after the game. Tag a player by tapping their name. Private messages are unlocked once with coins.';

  @override
  String get reactionsTitle => 'Reactions';

  @override
  String get reactionsInfoHelp =>
      'Send a reaction (fire, sleep, clap, wow) during results or at the end. Free, no moderation.';

  @override
  String get wordReviewTitle => 'Word review';

  @override
  String get wordReviewHelp =>
      'After the game, revisit found words (especially unique ones ⭐) with facts: capital, continent, diet…';

  @override
  String get salonTitleChampion => 'Champion';

  @override
  String get salonTitleSpeedster => 'Speedster';

  @override
  String get salonTitleRare => 'Rare finder';

  @override
  String get salonTitleDictionary => 'Walking dictionary';

  @override
  String get salonTitlesHelp =>
      'At the end, fun titles are awarded: champion, fastest, rare-word hunter, biggest vocabulary.';

  @override
  String rematchVote(int votes, int need) {
    return 'REMATCH ($votes/$need)';
  }

  @override
  String get rematchHelp =>
      'Vote to play again. When a majority of human players vote, a new game starts with the same settings.';

  @override
  String get bonusRound => 'BONUS ROUND';

  @override
  String get bonusRoundHelp =>
      'A surprise mini-round after the podium, with no stake. For anyone who wants one more round before leaving.';

  @override
  String get errorFrozen => 'You\'re frozen right now!';

  @override
  String get errorNoFreezes => 'No Freezes left';

  @override
  String get errorChatLocked => 'Unlock chat first';

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
    return 'Join my Mind Race game! Code: $code';
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
  String noticeHintUsed(String name, String category) {
    return '$name used a joker ($category)';
  }

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
  String get settingsGender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get settingsMusicVolume => 'Music volume';

  @override
  String get onboardingTitle => 'Welcome!';

  @override
  String get onboardingSubtitle => 'Set up your experience in a few seconds.';

  @override
  String get onboardingContinue => 'LET\'S GO!';

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
  String get voiceChatTitle => 'Voice lobby';

  @override
  String get voiceChatHelp =>
      'Talk during the match. Mute yourself anytime. The host can mute one mic, mute everyone, or remove someone from voice.';

  @override
  String get voiceJoin => 'JOIN';

  @override
  String get voiceConnecting => 'CONNECTING…';

  @override
  String get voiceMuteSelf => 'MUTE ME';

  @override
  String get voiceUnmuteSelf => 'UNMUTE ME';

  @override
  String get voiceMuteAll => 'MUTE EVERYONE';

  @override
  String get voiceUnmuteAll => 'UNMUTE EVERYONE';

  @override
  String get voiceMutePlayer => 'Mute';

  @override
  String get voiceUnmutePlayer => 'Unmute';

  @override
  String get voiceExcludePlayer => 'Remove from voice';

  @override
  String get voiceHostMutedYou => 'The host muted your mic.';

  @override
  String get voiceKickedNotice => 'The host removed you from voice.';

  @override
  String get voiceMutedBadge => 'Muted';

  @override
  String get voiceExcludedBadge => 'Removed from voice';

  @override
  String get voiceHostBadge => 'Host';

  @override
  String get voiceUnavailable => 'Voice not configured on the server (Agora).';

  @override
  String get errorVoiceUnavailable => 'Voice lobby unavailable.';

  @override
  String get errorVoiceClosed =>
      'Voice isn\'t open yet (wait for the match to start).';

  @override
  String get errorVoiceExcluded => 'You are excluded from voice.';

  @override
  String get errorMicDenied => 'Allow the microphone to talk.';

  @override
  String get rulesButton => 'Rules';

  @override
  String get eliminationRulesTitle => 'Rules';

  @override
  String get eliminationRulesIntro =>
      'Read the rules before you set up your competition.';

  @override
  String eliminationRules(int rounds) {
    return 'No solo: play with friends, in a duel, or against bots. All categories. Each round the lowest score is out (with 2 players: only on the last). Last one standing wins (up to $rounds rounds)!';
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
  String get formatRounds => 'Rounds';

  @override
  String get formatElimination => 'Knockout';

  @override
  String get formatRoundsHelp => 'Every round is played: the best total wins.';

  @override
  String get formatEliminationHelp =>
      'Each round, the lowest score is knocked out (with 2 players: only on the last round). The last one standing wins.';

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
  String get strictSpelling => 'Strict spelling';

  @override
  String get strictSpellingHelp =>
      'Case, accents and spaces must match the entry. Rounds of at least 2 minutes.';

  @override
  String get strictSpellingChip => 'Strict spelling';

  @override
  String get preparingGame => 'Getting the game ready…';

  @override
  String get playAlone => 'PLAY ALONE';

  @override
  String get withFriends => 'Start the competition';

  @override
  String get withFriendsHelp =>
      'Invite friends (code), join a room, or play right away against bots. You can also add bots in the lobby while waiting for friends.';

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

  @override
  String get perksFreeCoins => 'Free coins';

  @override
  String perksWatchInfo(int coins, int left) {
    return 'Watch a short video and earn $coins coins. $left left today.';
  }

  @override
  String perksWatch(int coins) {
    return 'WATCH (+$coins)';
  }

  @override
  String get perksAdLimit => 'No more videos today: come back tomorrow!';

  @override
  String get perksAdPending => 'Video watched! Your coins are on their way.';

  @override
  String get perksNoAd => 'No video available right now.';

  @override
  String get perksPassTitle => 'Mind Race Pass';

  @override
  String get perksPassNoAds => 'No ads between games';

  @override
  String perksPassDaily(int coins) {
    return '$coins free coins every day';
  }

  @override
  String perksPassHints(int hints) {
    return '$hints extra hints in every game';
  }

  @override
  String perksPassActive(String date) {
    return 'Pass active until $date';
  }

  @override
  String perksPassPrice(String price) {
    return 'SUBSCRIBE · $price / month';
  }

  @override
  String perksClaimDaily(int coins) {
    return 'CLAIM MY $coins COINS';
  }

  @override
  String get perksDailyTaken => 'DAILY BONUS CLAIMED';

  @override
  String get perksPassDone => 'Welcome to the Pass!';

  @override
  String get perksRemoveAdsTitle => 'No ads';

  @override
  String get perksRemoveAdsInfo =>
      'No more ads between games, forever. Videos to earn coins stay available.';

  @override
  String get perksRemoveAdsOwned => 'No ads: on';

  @override
  String get perksRemoveAdsDone => 'No more ads, thank you!';

  @override
  String get shopUnavailableShort => 'Unavailable';

  @override
  String roomHistoryTitle(String code) {
    return 'Room $code';
  }

  @override
  String get historyGames => 'Games';

  @override
  String get historyGroup => 'Group';

  @override
  String get historyPrivate => 'Private';

  @override
  String get historyUnavailable => 'History unavailable right now.';

  @override
  String get historyNoGames => 'No finished game in this room yet.';

  @override
  String get historyNoMessages => 'Nobody has written in the group yet.';

  @override
  String get historyNoPrivate =>
      'No private conversation. Open the room chat, then “Private”, to write to a player.';

  @override
  String privateChatEmpty(String name) {
    return 'Write your first message to $name.';
  }

  @override
  String get privateChatJoinRoom => 'Join the room to reply.';

  @override
  String privateChatUnlock(int price) {
    return 'Unlock private messages ($price coins)';
  }

  @override
  String privateChatHint(String name) {
    return 'Message to $name';
  }

  @override
  String get myRoomsTitle => 'My rooms';

  @override
  String get allPublicRoomsTitle => 'All public rooms';

  @override
  String savedRoomInfo(int members, String date) {
    return '$members players · $date';
  }

  @override
  String savedRoomOpen(int count) {
    return '$count inside';
  }

  @override
  String get savedRoomClosed => 'Closed';

  @override
  String get roomChatButton => 'CHAT';

  @override
  String get roomHistoryButton => 'HISTORY';

  @override
  String get chatPrivateButton => 'Private';

  @override
  String get chatPrivatePick => 'Who do you want to write to?';

  @override
  String chatMentionedBy(String name) {
    return '$name tagged you in the chat';
  }

  @override
  String get chatTagHint => 'Tap a name to tag them (@name).';

  @override
  String get settingsCountry => 'Home country';

  @override
  String get countryPickTitle => 'Your home country';

  @override
  String get countrySearch => 'Search a country';

  @override
  String get countryChoose => 'Choose';

  @override
  String get mixedLanguages => 'FR + EN: each in their own language';

  @override
  String get iqKindSequence => 'Sequence';

  @override
  String get iqKindGrid => 'Grid';

  @override
  String get iqKindProblem => 'Problem';

  @override
  String get iqKindLetters => 'Letters';

  @override
  String get iqKindCalendar => 'Calendar';

  @override
  String get iqKindAnalogy => 'Analogy';

  @override
  String get iqKindOdd => 'Odd one out';

  @override
  String get iqKindLogic => 'Logic';

  @override
  String get iqTypeAnswer => 'Type your answer';

  @override
  String get iqValidate => 'SUBMIT';

  @override
  String get iqGoodAnswer => 'Right answer';

  @override
  String iqQuestion(int number, int total) {
    return 'Puzzle $number / $total';
  }

  @override
  String get iqAnswerSent => 'Answer sent! Waiting for the others…';

  @override
  String get iqTitle => 'IQ';

  @override
  String get gamesTitle => 'Pick your game';

  @override
  String get gameLettersTitle => 'Geography & Nature';

  @override
  String get gameLettersInfo =>
      'One letter, several categories: cities, countries, animals, fruits, names…';

  @override
  String get gameIqTitle => 'IQ';

  @override
  String get gameIqInfo =>
      'Logical sequences, maths, analogies, odd ones out, riddles: who has the best IQ?';

  @override
  String get iqCreateRoom => 'CREATE AN IQ ROOM';

  @override
  String get iqSolo => 'SOLO';

  @override
  String get iqBots => 'AGAINST BOTS';

  @override
  String get iqOpenRooms => 'Open IQ rooms';

  @override
  String get iqNoRooms => 'No public IQ room right now: create yours!';

  @override
  String get iqRoomTitle => 'New IQ room';

  @override
  String get iqSoloTitle => 'Solo IQ';

  @override
  String get iqBotsTitle => 'IQ against bots';

  @override
  String get iqQuestions => 'Puzzles';

  @override
  String get iqTimePerQuestion => 'Time per puzzle';

  @override
  String get iqScoring => 'Points';

  @override
  String get iqSpeedBonus => 'Speed bonus (up to +10)';

  @override
  String get iqPenalty => 'Penalty if wrong (−5)';

  @override
  String get iqResultTitle => 'Your estimated IQ';

  @override
  String iqResultScore(int correct, int total, int points) {
    return '$correct right answers out of $total · $points points';
  }

  @override
  String get iqResultNote => 'Just for fun: this is not a real IQ test.';

  @override
  String get iqNext => 'NEXT PUZZLE';

  @override
  String get iqSeeResult => 'SEE MY IQ';

  @override
  String get iqBadge => 'IQ';

  @override
  String get iqYou => 'You';

  @override
  String get iqRelayHelp =>
      'Everyone gets their own puzzle, of the same level: no copying from your neighbour!';

  @override
  String get iqKindMatrix => 'Matrix';

  @override
  String get iqKindRotation => 'Rotation';

  @override
  String get iqKindFigureOdd => 'Visual odd one';

  @override
  String get iqJokerFifty => '50/50';

  @override
  String get iqJokerHint => 'Hint';

  @override
  String get iqJokerTime => '+15 s';

  @override
  String get iqJokerSkip => 'Skip';

  @override
  String iqHintRange(int low, int high) {
    return 'Hint: between $low and $high';
  }

  @override
  String iqCoinsWon(int coins) {
    return '+$coins coin(s) won';
  }

  @override
  String get iqOfflineNoCoins => 'Offline: no coins or jokers in this game.';

  @override
  String get iqDailyTitle => 'Daily challenge';

  @override
  String get iqDailyInfo =>
      '10 puzzles, the same for everyone, one try a day, no jokers. Podium rewarded: 50, 30 and 20 coins.';

  @override
  String get iqDailyPlay => 'PLAY THE CHALLENGE';

  @override
  String get iqDailyDone => 'Already played today: come back tomorrow!';

  @override
  String iqDailyRank(int rank) {
    return 'Your rank: $rank';
  }

  @override
  String get iqDailyLeaderboard => 'Today\'s leaderboard';

  @override
  String get iqDailyYesterday => 'Yesterday\'s podium';

  @override
  String get iqDailyEmpty => 'Nobody has played yet today: be the first!';

  @override
  String get iqDailyNeedsOnline => 'The daily challenge is played online.';

  @override
  String get iqLate => 'Too late!';

  @override
  String get iqKindTrace => 'One stroke';

  @override
  String get iqTraceRestart => 'START OVER';

  @override
  String get iqTraceStuck => 'Stuck: lines are left, start over!';

  @override
  String get iqTraceStartHint => 'Hint: start from the orange dot.';

  @override
  String get errorRoomDeleted => 'The creator deleted this room.';

  @override
  String get errorNotRoomCreator => 'Only the room\'s creator can delete it.';

  @override
  String get deleteRoomTitle => 'Delete the room';

  @override
  String get deleteRoomMessage =>
      'The room, its games and its chats will be erased for everyone. Anyone inside will leave.';

  @override
  String get deleteRoomConfirm => 'DELETE';

  @override
  String get roomDeleted => 'Room deleted.';

  @override
  String publicRoomAudience(int count) {
    return '$count other player(s) online will see it and can join.';
  }

  @override
  String get gameLettersTag => 'Letters & categories';

  @override
  String get gameIqTag => 'Logic & puzzles';
}
