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
  String get hintedBadge => 'Joker';

  @override
  String get hintNoneLeft => 'Plus de joker pour cette partie.';

  @override
  String get hintUnavailable => 'Pas de joker possible ici.';

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
}
