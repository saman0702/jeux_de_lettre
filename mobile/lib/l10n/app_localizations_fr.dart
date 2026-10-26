// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Letter Race';

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
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get winnerPrize => 'Dotation du vainqueur';

  @override
  String get winnerPrizeHelp =>
      'Tu places des pièces en créant la compétition ; seul le vainqueur les récupère. Les autres ne paient rien.';

  @override
  String get noPrize => 'Sans dotation';

  @override
  String get prizeCustomHint => 'Autre montant';

  @override
  String prizePotLabel(int coins) {
    return 'Dotation : $coins pièces';
  }

  @override
  String prizeLost(int coins) {
    return 'Dotation perdue ($coins)';
  }

  @override
  String get playVsBot => 'JOUER CONTRE UN BOT';

  @override
  String get playVsBots => 'JOUER CONTRE DES BOTS';

  @override
  String get eliminationBotDifficultyHelp =>
      'Niveau des bots si tu joues contre l\'ordinateur.';

  @override
  String noticeLeftGame(String name) {
    return '$name a quitté la partie';
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
  String get confirm => 'OK';

  @override
  String get roomFormat => 'Format';

  @override
  String get formatRelay => 'Relais';

  @override
  String get formatRelayHelp =>
      'Chaque joueur ne joue qu\'une partie des catégories (réparties). Il faut se coordonner… ou profiter des trous des autres !';

  @override
  String get formatRoundsHelpLong =>
      'Tout le monde joue toutes les manches. À la fin, le meilleur score total gagne. Classique et clair.';

  @override
  String get formatEliminationHelpLong =>
      'Après chaque manche, le plus petit score sort (à 2 joueurs : seulement à la dernière). Le dernier en lice gagne.';

  @override
  String get roomTheme => 'Thème du jour';

  @override
  String get roomThemeHelp =>
      'Les catégories du thème rapportent le double de points. Choisis géo, prénoms ou nature pour pimenter la partie.';

  @override
  String get visibilityHelp =>
      'Public : tous les joueurs connectés sont prévenus et peuvent rejoindre d\'un tap, sans code. Privé : seuls ceux qui ont le code peuvent entrer.';

  @override
  String get publicRoomLobbyHelp =>
      'Salon public : visible par tous les joueurs connectés. Ils peuvent rejoindre sans code depuis « Salons ».';

  @override
  String publicRoomInvite(String host) {
    return 'Nouveau salon public de $host';
  }

  @override
  String get joinPublicRoom => 'REJOINDRE';

  @override
  String get joinWithCodeHelp => 'Pour un salon privé uniquement';

  @override
  String get difficultyHelp =>
      'Facile = lettres courantes. Difficile = toutes les lettres, y compris K, W, X, Y, Z.';

  @override
  String get roomTypeHelp =>
      'Duel = 2 joueurs. Groupe = jusqu\'à 8. Plus on est nombreux, plus les points partagés baissent.';

  @override
  String get durationHelp =>
      'Temps pour remplir toutes les catégories. Plus de catégories ou orthographe stricte = durée minimum plus longue.';

  @override
  String get themeNone => 'Aucun';

  @override
  String get themeGeography => 'Géo (×2 villes & pays)';

  @override
  String get themeNames => 'Prénoms (×2)';

  @override
  String get themeNature => 'Nature (×2 animaux & fruits)';

  @override
  String freezeUse(int count) {
    return 'FREEZE ($count)';
  }

  @override
  String get freezeBuyTitle => 'Acheter un Freeze';

  @override
  String freezeBuyHelp(int price) {
    return 'Bloque un adversaire 10 secondes. Coût : $price pièces.\nTu en as 1 gratuit par partie.';
  }

  @override
  String get freezeInfoHelp =>
      'Pendant la manche, gèle un adversaire 10 secondes : il ne peut pas valider. 1 Freeze gratuit par partie, puis 15 pièces pour en racheter.';

  @override
  String get freezePickTarget => 'Qui geler ?';

  @override
  String get freezeAlready => 'Déjà gelé';

  @override
  String get freezeYouAreFrozen => '❄ Tu es gelé ! Attends un peu…';

  @override
  String get lightningTitle => 'Éclair !';

  @override
  String lightningHelp(String category, String letter, int seconds) {
    return '$category en $letter — ${seconds}s';
  }

  @override
  String get lightningInfoHelp =>
      'Entre deux manches : un mini QCM de 10 secondes. La bonne réponse te donne +2 points bonus. Sois rapide !';

  @override
  String lightningHit(int points) {
    return 'Bien joué ! +$points';
  }

  @override
  String get lightningMiss => 'Raté !';

  @override
  String get chatTitle => 'Chat du salon';

  @override
  String get chatHint => 'Écris un message…';

  @override
  String get chatUnlockTitle => 'Débloquer les messages privés';

  @override
  String chatUnlockHelp(int price) {
    return 'Écris en privé à n\'importe quel joueur de ce salon (personne d\'autre ne vous lit). Coût : $price pièces, une fois pour ce salon.';
  }

  @override
  String chatUnlockButton(int price) {
    return 'PRIVÉ · $price';
  }

  @override
  String get chatInfoHelp =>
      'La discussion de groupe est gratuite et reste dans le salon, même après la partie. Tague un joueur en touchant son pseudo. Les messages privés se débloquent une fois avec des pièces.';

  @override
  String get reactionsTitle => 'Réactions';

  @override
  String get reactionsInfoHelp =>
      'Envoie une réaction (feu, dodo, clap, surprise) pendant les résultats ou à la fin. Gratuit, sans modération.';

  @override
  String get wordReviewTitle => 'Revue des mots';

  @override
  String get wordReviewHelp =>
      'Après la partie, retrouve les mots trouvés (surtout les uniques ⭐) avec des infos : capitale, continent, régime…';

  @override
  String get salonTitleChampion => 'Champion';

  @override
  String get salonTitleSpeedster => 'Éclair';

  @override
  String get salonTitleRare => 'Chasseur de pépites';

  @override
  String get salonTitleDictionary => 'Dictionnaire vivant';

  @override
  String get salonTitlesHelp =>
      'À la fin, des titres fun sont donnés : champion, le plus rapide, celui qui trouve des mots rares, le plus grand vocabulaire.';

  @override
  String rematchVote(int votes, int need) {
    return 'REVANCHE ($votes/$need)';
  }

  @override
  String get rematchHelp =>
      'Vote pour rejouer. Quand la majorité des joueurs humains a voté, une nouvelle partie démarre avec les mêmes réglages.';

  @override
  String get bonusRound => 'MANCHE BONUS';

  @override
  String get bonusRoundHelp =>
      'Une mini-manche surprise après le podium, sans mise. Pour ceux qui veulent encore une manche avant de partir.';

  @override
  String get errorFrozen => 'Tu es gelé pour le moment !';

  @override
  String get errorNoFreezes => 'Plus de Freeze';

  @override
  String get errorChatLocked => 'Débloque le chat d\'abord';

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

  @override
  String get modeQuickMatch => 'Partie rapide';

  @override
  String get modeRooms => 'Salons';

  @override
  String onlineCount(int count) {
    return '$count en ligne';
  }

  @override
  String get offlineShort => 'Hors ligne';

  @override
  String get nicknameTitle => 'Choisis ton pseudo';

  @override
  String get nicknameHint => 'Ton pseudo';

  @override
  String get nicknameConfirm => 'C\'EST PARTI !';

  @override
  String get roomsTitle => 'Salons';

  @override
  String get createRoom => 'CRÉER UNE SALLE';

  @override
  String get joinWithCode => 'Rejoindre avec un code';

  @override
  String get joinCodeTitle => 'Code de la salle';

  @override
  String get join => 'Rejoindre';

  @override
  String get publicRoomsTitle => 'Salons ouverts';

  @override
  String get noPublicRooms =>
      'Aucun salon ouvert pour l\'instant. Crée le tien !';

  @override
  String roomOf(String name) {
    return 'Salle de $name';
  }

  @override
  String roundsCount(int count) {
    return '$count manches';
  }

  @override
  String playersCount(int count, int max) {
    return '$count/$max';
  }

  @override
  String get createRoomTitle => 'Nouvelle salle';

  @override
  String get roomType => 'Type de partie';

  @override
  String get roomTypeDuel => 'Duel';

  @override
  String get roomTypeGroup => 'Groupe (8 max)';

  @override
  String get visibility => 'Visibilité';

  @override
  String get visibilityPublic => 'Publique';

  @override
  String get visibilityPrivate => 'Privée';

  @override
  String get create => 'CRÉER';

  @override
  String get roomCode => 'Code de la salle';

  @override
  String get copyCode => 'Copier';

  @override
  String get codeCopied => 'Code copié !';

  @override
  String get shareInvite => 'Inviter';

  @override
  String inviteMessage(String code) {
    return 'Rejoins ma partie Letter Race ! Code : $code';
  }

  @override
  String get waitingForPlayers => 'En attente de joueurs…';

  @override
  String get readyButton => 'JE SUIS PRÊT !';

  @override
  String get notReadyButton => 'PAS ENCORE';

  @override
  String get readyHint =>
      'La partie démarre quand tout le monde est prêt (2 joueurs minimum).';

  @override
  String quickStartsIn(int seconds) {
    return 'Début dans $seconds s';
  }

  @override
  String get searchingPlayers => 'Recherche de joueurs…';

  @override
  String get hostBadge => 'Hôte';

  @override
  String get readyBadge => 'Prêt';

  @override
  String get youBadge => 'Toi';

  @override
  String get answersSent => 'Réponses envoyées !';

  @override
  String get waitingOthers => 'En attente des autres joueurs…';

  @override
  String get spectating => 'Tu joueras dès la prochaine manche.';

  @override
  String get yourAnswers => 'Tes réponses';

  @override
  String get leaderboard => 'Classement';

  @override
  String nextRoundIn(int seconds) {
    return 'Manche suivante dans $seconds s';
  }

  @override
  String get podiumTitle => 'PODIUM';

  @override
  String get leaveRoom => 'QUITTER';

  @override
  String get leaveRoomMessage => 'Tu vas quitter la salle.';

  @override
  String noticeHintUsed(String name, String category) {
    return '$name utilise un joker ($category)';
  }

  @override
  String noticeJoined(String name) {
    return '$name a rejoint la salle';
  }

  @override
  String noticeLeft(String name) {
    return '$name a quitté la salle';
  }

  @override
  String noticeDisconnected(String name) {
    return '$name s\'est déconnecté';
  }

  @override
  String noticeReconnected(String name) {
    return '$name est de retour';
  }

  @override
  String get connectionLost => 'Connexion perdue… reconnexion';

  @override
  String get errorRoomNotFound => 'Salle introuvable.';

  @override
  String get errorRoomFull => 'Cette salle est complète.';

  @override
  String get errorGameInProgress => 'La partie est déjà en cours.';

  @override
  String get opponents => 'Adversaires';

  @override
  String get opponentsNone => 'Aucun';

  @override
  String get botLevel => 'Niveau des bots';

  @override
  String get addBot => 'Ajouter un bot';

  @override
  String get noticeBotsJoined => 'Personne en ligne : des bots te rejoignent !';

  @override
  String get errorNotHost => 'Seul l\'hôte peut faire ça.';

  @override
  String get botTag => 'Bot';

  @override
  String hintTitle(String category, String letter) {
    return 'Joker : $category en $letter';
  }

  @override
  String get hintSubtitle => 'Un seul de ces mots est juste !';

  @override
  String get statusHintWrong => 'Mauvais choix';

  @override
  String get statusAlreadyUsed => 'Déjà utilisé dans ce monde';

  @override
  String get hintedBadge => 'Joker';

  @override
  String get hintNoneLeft => 'Plus de joker pour cette partie.';

  @override
  String get hintUnavailable => 'Pas de joker possible ici.';

  @override
  String get buyHintTitle => 'Joker en plus';

  @override
  String buyHintMessage(int count) {
    return 'Acheter un joker pour $count pièces ?';
  }

  @override
  String buyHintConfirm(int count) {
    return '$count pièces';
  }

  @override
  String get buyInfoTitle => 'Infos';

  @override
  String buyInfoMessage(int count) {
    return 'Dévoiler les infos pour $count pièces ?';
  }

  @override
  String buyInfoConfirm(int count) {
    return '$count pièces';
  }

  @override
  String buyInfoButton(int count) {
    return 'Infos · $count pièces';
  }

  @override
  String get buyInfoFree => 'Infos';

  @override
  String get notOnlineForPurchase => 'Connecte-toi pour dépenser des pièces.';

  @override
  String get offlineModeNotice => 'Pas de connexion : partie solo hors ligne';

  @override
  String get settingsGameKeyboard => 'Clavier du jeu';

  @override
  String get keyNext => 'Suivant';

  @override
  String get keySpace => 'espace';

  @override
  String get settingsVoice => 'Voix du présentateur';

  @override
  String voiceYouWinRound1(String name) {
    return 'Bravo $name, tu remportes la manche !';
  }

  @override
  String voiceYouWinRound2(String name) {
    return 'Excellent $name ! Manche gagnée !';
  }

  @override
  String voiceOtherWinsRound1(String name) {
    return '$name remporte la manche !';
  }

  @override
  String voiceOtherWinsRound2(String name) {
    return 'Cette manche est pour $name !';
  }

  @override
  String get voiceEncourage1 => 'Courage, tu vas te rattraper !';

  @override
  String get voiceEncourage2 => 'Pas de panique, la prochaine est pour toi !';

  @override
  String get voiceEncourage3 => 'Allez, on lâche rien !';

  @override
  String get voiceTie => 'Égalité sur cette manche ! Tout reste à jouer !';

  @override
  String get voiceNobodyScored =>
      'Personne n\'a marqué ! Concentrez-vous, ça repart !';

  @override
  String voiceSoloGreat(int points) {
    return 'Superbe ! $points points !';
  }

  @override
  String voiceSoloGood(int points) {
    return 'Bien joué, $points points !';
  }

  @override
  String get voiceSoloLow => 'Allez, tu peux faire mieux à la prochaine !';

  @override
  String get voiceSoloZero => 'Aïe, aucun point ! Respire, tu vas y arriver !';

  @override
  String voiceYouWinGame(String name) {
    return 'Victoire ! Bravo $name, tu gagnes la partie !';
  }

  @override
  String voiceOtherWinsGame(String name) {
    return '$name gagne la partie ! Bien joué à tous. Une revanche ?';
  }

  @override
  String voiceSoloGameEnd(int points) {
    return 'Partie terminée ! $points points au total !';
  }

  @override
  String get dialogStay => 'RESTER';

  @override
  String get roundLabel => 'MANCHE';

  @override
  String get onlineLabel => 'EN LIGNE';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageAuto => 'Auto';

  @override
  String get settingsGender => 'Genre';

  @override
  String get genderMale => 'Homme';

  @override
  String get genderFemale => 'Femme';

  @override
  String get genderOther => 'Autre';

  @override
  String get settingsMusicVolume => 'Volume musique';

  @override
  String get onboardingTitle => 'Bienvenue !';

  @override
  String get onboardingSubtitle => 'Régle ton expérience en quelques secondes.';

  @override
  String get onboardingContinue => 'C\'EST PARTI !';

  @override
  String suggestionExample(String answer) {
    return 'Réponse possible : $answer';
  }

  @override
  String suggestionFoundBy(String name, String answer) {
    return '$name a trouvé : $answer';
  }

  @override
  String coinsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces',
      one: '1 pièce',
      zero: '0 pièce',
    );
    return '$_temp0';
  }

  @override
  String coinsGained(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces',
      one: '1 pièce',
    );
    return '+$_temp0';
  }

  @override
  String get roomKind => 'Salon';

  @override
  String get roomKindClassic => 'Classique';

  @override
  String get roomKindBet => 'Paris';

  @override
  String get stake => 'Mise par joueur';

  @override
  String stakeShort(int count) {
    return 'Mise $count';
  }

  @override
  String potLabel(int count) {
    return 'Pot : $count';
  }

  @override
  String get betRules =>
      'Chaque joueur mise la même somme. Le premier rafle tout, le pot est partagé en cas d\'égalité. Pas de bots.';

  @override
  String yourCoins(int count) {
    return 'Ton solde : $count';
  }

  @override
  String betWon(int count) {
    return 'Tu rafles $count pièces !';
  }

  @override
  String betLost(int count) {
    return 'Mise perdue : $count pièces';
  }

  @override
  String get errorNotEnoughCoins => 'Pas assez de pièces pour cette mise.';

  @override
  String get errorBotsNotAllowed => 'Pas de bots dans un salon de paris.';

  @override
  String get avatarTitle => 'Mon avatar';

  @override
  String get avatarCamera => 'PHOTO';

  @override
  String get avatarGallery => 'GALERIE';

  @override
  String get avatarPhotoInfo =>
      'Ta photo est transformée en dessin avant d\'être montrée aux autres joueurs.';

  @override
  String get avatarCharacters => 'Personnages';

  @override
  String get avatarUpdated => 'Avatar mis à jour !';

  @override
  String get errorInvalidImage => 'Cette image n\'a pas pu être lue.';

  @override
  String get errorFileTooLarge => 'Image trop lourde.';

  @override
  String get reportTitle => 'Signaler la photo ?';

  @override
  String reportMessage(String name) {
    return 'La photo de $name est retirée après plusieurs signalements.';
  }

  @override
  String get reportConfirm => 'SIGNALER';

  @override
  String get reportSent => 'Merci, signalement envoyé.';

  @override
  String get musicCredits =>
      'Musiques de Kevin MacLeod (incompetech.com), licence Creative Commons BY 4.0 : « Monkeys Spinning Monkeys », « Fluffing a Duck », « Carefree », « Pixel Peeker Polka », « Sneaky Snitch », « Investigations », « Run Amok », « Funkorama », « Itty Bitty 8 Bit », « Bit Quest ».';

  @override
  String get shopTitle => 'Boutique';

  @override
  String get shopCoinsLabel => 'pièces';

  @override
  String shopBonus(int percent) {
    return '+$percent %';
  }

  @override
  String shopBought(int count) {
    return '+$count pièces, merci !';
  }

  @override
  String get shopPending =>
      'Paiement en attente : tes pièces arriveront dès qu\'il sera confirmé.';

  @override
  String get shopInvalid => 'Cet achat n\'a pas pu être validé.';

  @override
  String get shopStoreError => 'L\'achat n\'a pas abouti.';

  @override
  String get shopRetryLater =>
      'Achat reçu : tes pièces seront ajoutées dès que le serveur sera joignable.';

  @override
  String get shopUnavailable =>
      'La boutique n\'est pas disponible sur cet appareil pour le moment.';

  @override
  String get shopLegal =>
      'Paiement sécurisé par Google Play ou l\'App Store. Les pièces n\'ont aucune valeur monétaire : elles ne sont ni remboursables, ni échangeables, ni convertibles en argent.';

  @override
  String get avatarPhotoNeedsConnection =>
      'Connecte-toi pour utiliser une photo : elle est transformée en dessin sur le serveur.';

  @override
  String get avatarPickFailed =>
      'Impossible d\'ouvrir l\'appareil photo ou la galerie. Vérifie les autorisations de l\'appli.';

  @override
  String get avatarSavedOffline =>
      'Avatar choisi ! Il sera partagé dès que tu seras en ligne.';

  @override
  String get credits => 'Crédits';

  @override
  String levelUp(int level) {
    return 'NIVEAU $level !';
  }

  @override
  String levelLabel(int level) {
    return 'Niveau $level';
  }

  @override
  String levelProgress(int xp, int needed) {
    return '$xp / $needed points avant le niveau suivant';
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
    return 'MINIMUM $points PTS : RÉUSSI !';
  }

  @override
  String challengeEliminated(int points) {
    return 'ÉLIMINÉ ! Il fallait $points pts';
  }

  @override
  String careerProgressBanner(int score, int target) {
    return 'Objectif : $score / $target pts';
  }

  @override
  String careerWon(int level) {
    return 'Niveau $level réussi !';
  }

  @override
  String careerLost(int level) {
    return 'Niveau $level raté';
  }

  @override
  String careerMessage(int target, int score) {
    return 'Objectif $target pts · tu as marqué $score pts';
  }

  @override
  String careerStarsInfo(int one, int two, int three) {
    return 'Étoiles à $one, $two et $three pts';
  }

  @override
  String get nextLevel => 'NIVEAU SUIVANT';

  @override
  String get replayLevel => 'REJOUER LE NIVEAU';

  @override
  String get levelsMap => 'CARTE DES NIVEAUX';

  @override
  String get eliminationChampion => 'Champion !';

  @override
  String get eliminationOut => 'Éliminé !';

  @override
  String eliminationMessage(int rounds, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      rounds,
      locale: localeName,
      other: '$rounds manches',
      one: '1 manche',
      zero: '0 manche',
    );
    return 'Tu as tenu $_temp0 sur $total';
  }

  @override
  String eliminationRecord(int rounds) {
    return 'Record : $rounds manches';
  }

  @override
  String eliminationNewRecord(int rounds) {
    return 'Nouveau record : $rounds manches !';
  }

  @override
  String get careerTitle => 'Carrière';

  @override
  String get careerRulesIntro =>
      '60 niveaux de 5 manches, en 4 mondes de 15. Une étoile ouvre le niveau suivant.';

  @override
  String get careerRulesFromConfirmed =>
      'Au monde Débutant, les catégories montent : Ville et Pays, puis Animal, puis Fruit. À partir du Confirmé, les prénoms s\'ajoutent. Ensuite les lettres durcissent et l\'objectif de points grimpe.';

  @override
  String get careerRulesStars =>
      '1 étoile à l\'objectif, puis 2 et 3 étoiles en t\'approchant du score parfait.';

  @override
  String get careerRulesBeginner =>
      'Lettres faciles, 60 puis 45 puis 30 secondes. Ville et Pays, puis Animal, puis Fruit.';

  @override
  String get careerRulesConfirmed =>
      'Lettres normales. Les quatre catégories, puis un prénom féminin en plus.';

  @override
  String get careerRulesExpert =>
      'Toutes les lettres, même les plus rares. Un prénom masculin en plus.';

  @override
  String get careerRulesMaster =>
      'Les six catégories, objectifs plus hauts. Il faut trouver de nouveaux mots.';

  @override
  String get careerRulesReuse =>
      'Dans le même monde, un mot déjà validé ne peut plus servir si la lettre revient.';

  @override
  String get gotIt => 'COMPRIS';

  @override
  String get worldBeginner => 'Débutant';

  @override
  String get worldConfirmed => 'Confirmé';

  @override
  String get worldExpert => 'Expert';

  @override
  String get worldMaster => 'Maître';

  @override
  String levelTitle(int level) {
    return 'Niveau $level';
  }

  @override
  String levelGoal(int target) {
    return 'Objectif : $target points';
  }

  @override
  String get play => 'JOUER';

  @override
  String get modeCareer => 'Carrière';

  @override
  String get modeElimination => 'Éliminatoires';

  @override
  String get modeFreeSolo => 'Solo libre';

  @override
  String get voiceChatTitle => 'Salon vocal';

  @override
  String get voiceChatHelp =>
      'Parlez pendant la partie. Coupez votre micro quand vous voulez. L\'hôte peut couper un micro, tous les micros, ou exclure quelqu\'un.';

  @override
  String get voiceJoin => 'REJOINDRE';

  @override
  String get voiceConnecting => 'CONNEXION…';

  @override
  String get voiceMuteSelf => 'COUPER MON MICRO';

  @override
  String get voiceUnmuteSelf => 'OUVRIR MON MICRO';

  @override
  String get voiceMuteAll => 'COUPER TOUS LES MICROS';

  @override
  String get voiceUnmuteAll => 'RENDRE LES MICROS';

  @override
  String get voiceMutePlayer => 'Couper le micro';

  @override
  String get voiceUnmutePlayer => 'Rendre le micro';

  @override
  String get voiceExcludePlayer => 'Exclure du vocal';

  @override
  String get voiceHostMutedYou => 'L\'hôte a coupé ton micro.';

  @override
  String get voiceKickedNotice => 'L\'hôte t\'a exclu du salon vocal.';

  @override
  String get voiceMutedBadge => 'Micro coupé';

  @override
  String get voiceExcludedBadge => 'Exclu du vocal';

  @override
  String get voiceHostBadge => 'Hôte';

  @override
  String get voiceUnavailable => 'Vocal non configuré sur le serveur (Agora).';

  @override
  String get errorVoiceUnavailable => 'Salon vocal indisponible.';

  @override
  String get errorVoiceClosed =>
      'Le vocal n\'est pas encore ouvert (attente du début de partie).';

  @override
  String get errorVoiceExcluded => 'Tu es exclu du salon vocal.';

  @override
  String get errorMicDenied => 'Autorise le micro pour parler.';

  @override
  String get rulesButton => 'Règle';

  @override
  String get eliminationRulesTitle => 'Règle';

  @override
  String get eliminationRulesIntro =>
      'Lis la règle avant de régler ta compétition.';

  @override
  String eliminationRules(int rounds) {
    return 'Pas de solo : joue avec des amis, en duel, ou contre des bots. Toutes les catégories. À chaque manche, le plus petit score sort (à 2 joueurs : seulement à la dernière). Le dernier en lice remporte la compétition ($rounds manches max) !';
  }

  @override
  String roundsRange(int from, int to) {
    return 'Manches $from à $to';
  }

  @override
  String get eliminationBestTitle => 'Ton record';

  @override
  String get eliminationNoRecord => 'Pas encore de record';

  @override
  String get formatRounds => 'Par manches';

  @override
  String get formatElimination => 'Éliminatoires';

  @override
  String get formatRoundsHelp =>
      'Toutes les manches sont jouées : le meilleur total gagne.';

  @override
  String get formatEliminationHelp =>
      'À chaque manche, le plus petit score est éliminé (à 2 joueurs : seulement à la dernière manche). Le dernier en lice gagne.';

  @override
  String get youAreEliminated =>
      'Tu es éliminé : regarde la fin de la partie !';

  @override
  String get youAreOut => 'Tu es éliminé !';

  @override
  String playerIsOut(String name) {
    return '$name est éliminé !';
  }

  @override
  String get categoryFemaleName => 'Prénom féminin';

  @override
  String get categoryMaleName => 'Prénom masculin';

  @override
  String manyCategoriesHint(int count) {
    return '$count catégories ou plus : 45 secondes minimum par manche.';
  }

  @override
  String get strictSpelling => 'Orthographe stricte';

  @override
  String get strictSpellingHelp =>
      'Casse, accents et espaces doivent coller à la fiche. Manches d\'au moins 2 minutes.';

  @override
  String get strictSpellingChip => 'Orthographe stricte';

  @override
  String get preparingGame => 'Préparation de la partie…';

  @override
  String get playAlone => 'JOUER SEUL';

  @override
  String get withFriends => 'Lancer la compétition';

  @override
  String get withFriendsHelp =>
      'Invite des amis (code), rejoins un salon, ou joue tout de suite contre des bots. Tu peux aussi ajouter des bots dans le lobby en attendant tes amis.';

  @override
  String get inviteFriends => 'INVITER DES AMIS';

  @override
  String get looksTitle => 'Boutique style';

  @override
  String get looksSubtitle => 'Essaie un look, puis achète-le avec tes pièces.';

  @override
  String get looksPreview => 'Ton aperçu';

  @override
  String get looksPacks => 'Packs';

  @override
  String get looksHair => 'Coiffures';

  @override
  String get looksHat => 'Chapeaux';

  @override
  String get looksFrame => 'Cadres';

  @override
  String get looksName => 'Pseudos';

  @override
  String get looksTiles => 'Tuiles';

  @override
  String get looksVictory => 'Victoire';

  @override
  String get looksPacksHint => 'Plusieurs styles assortis, moins cher en lot.';

  @override
  String get looksHairHint => 'Change de coupe sans toucher à ton personnage.';

  @override
  String get looksHatHint => 'Couronnes, casquettes et chapeaux magiques.';

  @override
  String get looksFrameHint => 'Anneaux, ornements, flammes ou étoiles.';

  @override
  String get looksNameHint =>
      'Couleur, dégradé, contour ou badge devant le pseudo.';

  @override
  String get looksTilesHint => 'Couleurs et motifs des cases quand tu joues.';

  @override
  String get looksVictoryHint =>
      'Confettis, étoiles, bulles ou pluie de lettres.';

  @override
  String get looksHairSpiky => 'Hérisson';

  @override
  String get looksHairBob => 'Carré rose';

  @override
  String get looksHairCurly => 'Boucles bleues';

  @override
  String get looksHairBun => 'Chignon or';

  @override
  String get looksHatCrown => 'Couronne';

  @override
  String get looksHatCap => 'Casquette';

  @override
  String get looksHatWizard => 'Chapeau mage';

  @override
  String get looksHatParty => 'Fête';

  @override
  String get looksFrameOrnament => 'Ornement';

  @override
  String get looksFrameFlames => 'Flammes';

  @override
  String get looksFrameStars => 'Étoiles';

  @override
  String get looksNameGradient => 'Dégradé';

  @override
  String get looksNameOutline => 'Contour';

  @override
  String get looksNameBadge => 'Badge';

  @override
  String get looksTilesStripes => 'Rayures';

  @override
  String get looksTilesDots => 'Pois';

  @override
  String get looksTilesMetal => 'Métal';

  @override
  String get looksVictoryStars => 'Étoiles';

  @override
  String get looksVictoryBubbles => 'Bulles';

  @override
  String get looksVictoryLetters => 'Lettres';

  @override
  String get looksPackOcean => 'Pack Océan';

  @override
  String get looksPackCandy => 'Pack Bonbon';

  @override
  String get looksPackRoyal => 'Pack Royal';

  @override
  String looksPackContents(int count) {
    return '$count styles';
  }

  @override
  String get looksOwned => 'POSSEDÉ';

  @override
  String get looksEquip => 'ÉQUIPER';

  @override
  String get looksEquipped => 'ÉQUIPÉ';

  @override
  String looksPrice(int count) {
    return '$count pièces';
  }

  @override
  String get looksNotEnough => 'Pas assez de pièces.';

  @override
  String get looksGold => 'Or';

  @override
  String get looksPink => 'Rose';

  @override
  String get looksCyan => 'Cyan';

  @override
  String get looksViolet => 'Violet';

  @override
  String get looksOrange => 'Orange';

  @override
  String get looksMint => 'Menthe';

  @override
  String get perksFreeCoins => 'Pièces gratuites';

  @override
  String perksWatchInfo(int coins, int left) {
    return 'Regarde une courte vidéo et gagne $coins pièces. Encore $left aujourd\'hui.';
  }

  @override
  String perksWatch(int coins) {
    return 'REGARDER (+$coins)';
  }

  @override
  String get perksAdLimit =>
      'Plus de vidéo pour aujourd\'hui : reviens demain !';

  @override
  String get perksAdPending =>
      'Vidéo vue ! Tes pièces arrivent dans un instant.';

  @override
  String get perksNoAd => 'Pas de vidéo disponible pour le moment.';

  @override
  String get perksPassTitle => 'Pass Letter Race';

  @override
  String get perksPassNoAds => 'Aucune pub entre les parties';

  @override
  String perksPassDaily(int coins) {
    return '$coins pièces offertes chaque jour';
  }

  @override
  String perksPassHints(int hints) {
    return '$hints jokers en plus dans chaque partie';
  }

  @override
  String perksPassActive(String date) {
    return 'Pass actif jusqu\'au $date';
  }

  @override
  String perksPassPrice(String price) {
    return 'S\'ABONNER · $price / mois';
  }

  @override
  String perksClaimDaily(int coins) {
    return 'PRENDRE MES $coins PIÈCES';
  }

  @override
  String get perksDailyTaken => 'BONUS DU JOUR PRIS';

  @override
  String get perksPassDone => 'Bienvenue dans le Pass !';

  @override
  String get perksRemoveAdsTitle => 'Sans pub';

  @override
  String get perksRemoveAdsInfo =>
      'Plus aucune pub entre les parties, pour toujours. Les vidéos pour gagner des pièces restent possibles.';

  @override
  String get perksRemoveAdsOwned => 'Sans pub : activé';

  @override
  String get perksRemoveAdsDone => 'C\'est fini les pubs, merci !';

  @override
  String get shopUnavailableShort => 'Indisponible';

  @override
  String roomHistoryTitle(String code) {
    return 'Salon $code';
  }

  @override
  String get historyGames => 'Parties';

  @override
  String get historyGroup => 'Groupe';

  @override
  String get historyPrivate => 'Privé';

  @override
  String get historyUnavailable => 'Historique indisponible pour le moment.';

  @override
  String get historyNoGames =>
      'Aucune partie terminée dans ce salon pour l\'instant.';

  @override
  String get historyNoMessages => 'Personne n\'a encore écrit dans le groupe.';

  @override
  String get historyNoPrivate =>
      'Aucune conversation privée. Ouvre la discussion du salon, puis « Privé », pour écrire à un joueur.';

  @override
  String privateChatEmpty(String name) {
    return 'Écris ton premier message à $name.';
  }

  @override
  String get privateChatJoinRoom => 'Rejoins le salon pour répondre.';

  @override
  String privateChatUnlock(int price) {
    return 'Débloquer les messages privés ($price pièces)';
  }

  @override
  String privateChatHint(String name) {
    return 'Message à $name';
  }

  @override
  String get myRoomsTitle => 'Mes salons';

  @override
  String get allPublicRoomsTitle => 'Tous les salons publics';

  @override
  String savedRoomInfo(int members, String date) {
    return '$members joueurs · $date';
  }

  @override
  String savedRoomOpen(int count) {
    return '$count dedans';
  }

  @override
  String get savedRoomClosed => 'Fermé';

  @override
  String get roomChatButton => 'DISCUSSION';

  @override
  String get roomHistoryButton => 'HISTORIQUE';

  @override
  String get chatPrivateButton => 'Privé';

  @override
  String get chatPrivatePick => 'À qui veux-tu écrire ?';

  @override
  String chatMentionedBy(String name) {
    return '$name t\'a tagué dans la discussion';
  }

  @override
  String get chatTagHint => 'Touche un pseudo pour le taguer (@pseudo).';

  @override
  String get settingsCountry => 'Pays d\'origine';

  @override
  String get countryPickTitle => 'Ton pays d\'origine';

  @override
  String get countrySearch => 'Rechercher un pays';

  @override
  String get countryChoose => 'Choisir';

  @override
  String get mixedLanguages => 'FR + EN : chacun dans sa langue';

  @override
  String get iqKindSequence => 'Suite';

  @override
  String get iqKindGrid => 'Grille';

  @override
  String get iqKindProblem => 'Problème';

  @override
  String get iqKindLetters => 'Lettres';

  @override
  String get iqKindCalendar => 'Calendrier';

  @override
  String get iqKindAnalogy => 'Analogie';

  @override
  String get iqKindOdd => 'Intrus';

  @override
  String get iqKindLogic => 'Logique';

  @override
  String get iqTypeAnswer => 'Tape ta réponse';

  @override
  String get iqValidate => 'VALIDER';

  @override
  String get iqGoodAnswer => 'Bonne réponse';

  @override
  String iqQuestion(int number, int total) {
    return 'Énigme $number / $total';
  }

  @override
  String get iqAnswerSent => 'Réponse envoyée ! On attend les autres…';

  @override
  String get iqTitle => 'QI';

  @override
  String get gamesTitle => 'Choisis ton jeu';

  @override
  String get gameLettersTitle => 'Géographie & Nature';

  @override
  String get gameLettersInfo =>
      'Une lettre, des catégories : villes, pays, animaux, fruits, prénoms…';

  @override
  String get gameIqTitle => 'QI';

  @override
  String get gameIqInfo =>
      'Suites logiques, calcul, analogies, intrus, énigmes : qui a le meilleur QI ?';

  @override
  String get iqCreateRoom => 'CRÉER UN SALON QI';

  @override
  String get iqSolo => 'SOLO';

  @override
  String get iqBots => 'CONTRE LES BOTS';

  @override
  String get iqOpenRooms => 'Salons QI ouverts';

  @override
  String get iqNoRooms =>
      'Aucun salon QI public pour le moment : crée le tien !';

  @override
  String get iqRoomTitle => 'Nouveau salon QI';

  @override
  String get iqSoloTitle => 'QI en solo';

  @override
  String get iqBotsTitle => 'QI contre les bots';

  @override
  String get iqQuestions => 'Énigmes';

  @override
  String get iqTimePerQuestion => 'Temps par énigme';

  @override
  String get iqScoring => 'Points';

  @override
  String get iqSpeedBonus => 'Bonus de rapidité (jusqu\'à +10)';

  @override
  String get iqPenalty => 'Malus si c\'est faux (−5)';

  @override
  String get iqResultTitle => 'Ton QI estimé';

  @override
  String iqResultScore(int correct, int total, int points) {
    return '$correct bonnes réponses sur $total · $points points';
  }

  @override
  String get iqResultNote =>
      'Pour s\'amuser : ce n\'est pas un vrai test de QI.';

  @override
  String get iqNext => 'ÉNIGME SUIVANTE';

  @override
  String get iqSeeResult => 'VOIR MON QI';

  @override
  String get iqBadge => 'QI';

  @override
  String get iqYou => 'Toi';

  @override
  String get iqRelayHelp =>
      'Chacun reçoit sa propre énigme, du même niveau : impossible de copier sur le voisin !';

  @override
  String get iqKindMatrix => 'Matrice';

  @override
  String get iqKindRotation => 'Rotation';

  @override
  String get iqKindFigureOdd => 'Intrus visuel';

  @override
  String get iqJokerFifty => '50/50';

  @override
  String get iqJokerHint => 'Indice';

  @override
  String get iqJokerTime => '+15 s';

  @override
  String get iqJokerSkip => 'Passer';

  @override
  String iqHintRange(int low, int high) {
    return 'Indice : entre $low et $high';
  }

  @override
  String iqCoinsWon(int coins) {
    return '+$coins pièce(s) gagnée(s)';
  }

  @override
  String get iqOfflineNoCoins => 'Hors ligne : partie sans pièces ni jokers.';

  @override
  String get iqDailyTitle => 'Défi du jour';

  @override
  String get iqDailyInfo =>
      '10 énigmes, les mêmes pour tous, une seule tentative par jour, sans jokers. Podium récompensé : 50, 30 et 20 pièces.';

  @override
  String get iqDailyPlay => 'JOUER LE DÉFI';

  @override
  String get iqDailyDone => 'Déjà joué aujourd\'hui : reviens demain !';

  @override
  String iqDailyRank(int rank) {
    return 'Ton rang : $rank';
  }

  @override
  String get iqDailyLeaderboard => 'Classement du jour';

  @override
  String get iqDailyYesterday => 'Podium d\'hier';

  @override
  String get iqDailyEmpty =>
      'Personne n\'a encore joué aujourd\'hui : sois le premier !';

  @override
  String get iqDailyNeedsOnline => 'Le défi du jour se joue en ligne.';

  @override
  String get iqLate => 'Trop tard !';
}
