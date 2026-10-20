import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Letter Race'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In fr, this message translates to:
  /// **'Une lettre. Quatre catégories. Le plus rapide gagne.'**
  String get tagline;

  /// No description provided for @modeSolo.
  ///
  /// In fr, this message translates to:
  /// **'Solo'**
  String get modeSolo;

  /// No description provided for @modeDuel.
  ///
  /// In fr, this message translates to:
  /// **'Duel'**
  String get modeDuel;

  /// No description provided for @modeMultiplayer.
  ///
  /// In fr, this message translates to:
  /// **'Multijoueur'**
  String get modeMultiplayer;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoon;

  /// No description provided for @serverOnline.
  ///
  /// In fr, this message translates to:
  /// **'Serveur connecté'**
  String get serverOnline;

  /// No description provided for @serverOffline.
  ///
  /// In fr, this message translates to:
  /// **'Serveur injoignable'**
  String get serverOffline;

  /// No description provided for @serverChecking.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur…'**
  String get serverChecking;

  /// No description provided for @categoryCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get categoryCity;

  /// No description provided for @categoryCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get categoryCountry;

  /// No description provided for @categoryAnimal.
  ///
  /// In fr, this message translates to:
  /// **'Animal'**
  String get categoryAnimal;

  /// No description provided for @categoryFruit.
  ///
  /// In fr, this message translates to:
  /// **'Fruit'**
  String get categoryFruit;

  /// No description provided for @soloSetupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partie solo'**
  String get soloSetupTitle;

  /// No description provided for @rounds.
  ///
  /// In fr, this message translates to:
  /// **'Manches'**
  String get rounds;

  /// No description provided for @roundDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée d\'une manche'**
  String get roundDuration;

  /// No description provided for @secondsShort.
  ///
  /// In fr, this message translates to:
  /// **'{seconds} s'**
  String secondsShort(int seconds);

  /// No description provided for @minutesShort.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @winnerPrize.
  ///
  /// In fr, this message translates to:
  /// **'Dotation du vainqueur'**
  String get winnerPrize;

  /// No description provided for @winnerPrizeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Tu places des pièces en créant la compétition ; seul le vainqueur les récupère. Les autres ne paient rien.'**
  String get winnerPrizeHelp;

  /// No description provided for @noPrize.
  ///
  /// In fr, this message translates to:
  /// **'Sans dotation'**
  String get noPrize;

  /// No description provided for @prizeCustomHint.
  ///
  /// In fr, this message translates to:
  /// **'Autre montant'**
  String get prizeCustomHint;

  /// No description provided for @prizePotLabel.
  ///
  /// In fr, this message translates to:
  /// **'Dotation : {coins} pièces'**
  String prizePotLabel(int coins);

  /// No description provided for @prizeLost.
  ///
  /// In fr, this message translates to:
  /// **'Dotation perdue ({coins})'**
  String prizeLost(int coins);

  /// No description provided for @playVsBot.
  ///
  /// In fr, this message translates to:
  /// **'JOUER CONTRE UN BOT'**
  String get playVsBot;

  /// No description provided for @playVsBots.
  ///
  /// In fr, this message translates to:
  /// **'JOUER CONTRE DES BOTS'**
  String get playVsBots;

  /// No description provided for @eliminationBotDifficultyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Niveau des bots si tu joues contre l\'ordinateur.'**
  String get eliminationBotDifficultyHelp;

  /// No description provided for @noticeLeftGame.
  ///
  /// In fr, this message translates to:
  /// **'{name} a quitté la partie'**
  String noticeLeftGame(String name);

  /// No description provided for @categories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categories;

  /// No description provided for @selectOneCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisis au moins une catégorie'**
  String get selectOneCategory;

  /// No description provided for @difficulty.
  ///
  /// In fr, this message translates to:
  /// **'Difficulté'**
  String get difficulty;

  /// No description provided for @difficultyEasy.
  ///
  /// In fr, this message translates to:
  /// **'Facile'**
  String get difficultyEasy;

  /// No description provided for @difficultyNormal.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get difficultyNormal;

  /// No description provided for @difficultyHard.
  ///
  /// In fr, this message translates to:
  /// **'Difficile'**
  String get difficultyHard;

  /// No description provided for @startGame.
  ///
  /// In fr, this message translates to:
  /// **'JOUER'**
  String get startGame;

  /// No description provided for @defaultNickname.
  ///
  /// In fr, this message translates to:
  /// **'Joueur'**
  String get defaultNickname;

  /// No description provided for @roundProgress.
  ///
  /// In fr, this message translates to:
  /// **'Manche {current} / {total}'**
  String roundProgress(int current, int total);

  /// No description provided for @letterLabel.
  ///
  /// In fr, this message translates to:
  /// **'LETTRE'**
  String get letterLabel;

  /// No description provided for @finish.
  ///
  /// In fr, this message translates to:
  /// **'TERMINER'**
  String get finish;

  /// No description provided for @go.
  ///
  /// In fr, this message translates to:
  /// **'GO !'**
  String get go;

  /// No description provided for @statusValid.
  ///
  /// In fr, this message translates to:
  /// **'Valide'**
  String get statusValid;

  /// No description provided for @statusEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse'**
  String get statusEmpty;

  /// No description provided for @statusWrongLetter.
  ///
  /// In fr, this message translates to:
  /// **'Mauvaise lettre'**
  String get statusWrongLetter;

  /// No description provided for @statusNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inconnue'**
  String get statusNotFound;

  /// No description provided for @statusLate.
  ///
  /// In fr, this message translates to:
  /// **'Temps écoulé'**
  String get statusLate;

  /// No description provided for @pointsShort.
  ///
  /// In fr, this message translates to:
  /// **'{points} pts'**
  String pointsShort(int points);

  /// No description provided for @roundScore.
  ///
  /// In fr, this message translates to:
  /// **'Score de la manche'**
  String get roundScore;

  /// No description provided for @totalScore.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalScore;

  /// No description provided for @finishedIn.
  ///
  /// In fr, this message translates to:
  /// **'Terminé en {seconds} s'**
  String finishedIn(String seconds);

  /// No description provided for @nextRound.
  ///
  /// In fr, this message translates to:
  /// **'MANCHE SUIVANTE'**
  String get nextRound;

  /// No description provided for @seeResults.
  ///
  /// In fr, this message translates to:
  /// **'VOIR LE RÉSULTAT'**
  String get seeResults;

  /// No description provided for @gameOver.
  ///
  /// In fr, this message translates to:
  /// **'PARTIE TERMINÉE'**
  String get gameOver;

  /// No description provided for @playAgain.
  ///
  /// In fr, this message translates to:
  /// **'REJOUER'**
  String get playAgain;

  /// No description provided for @backHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get backHome;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au serveur impossible.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get errorGeneric;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @quitGameTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter la partie ?'**
  String get quitGameTitle;

  /// No description provided for @quitGameMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ta progression sera perdue.'**
  String get quitGameMessage;

  /// No description provided for @quit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get quit;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @roomFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get roomFormat;

  /// No description provided for @formatRelay.
  ///
  /// In fr, this message translates to:
  /// **'Relais'**
  String get formatRelay;

  /// No description provided for @formatRelayHelp.
  ///
  /// In fr, this message translates to:
  /// **'Chaque joueur ne joue qu\'une partie des catégories (réparties). Il faut se coordonner… ou profiter des trous des autres !'**
  String get formatRelayHelp;

  /// No description provided for @formatRoundsHelpLong.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde joue toutes les manches. À la fin, le meilleur score total gagne. Classique et clair.'**
  String get formatRoundsHelpLong;

  /// No description provided for @formatEliminationHelpLong.
  ///
  /// In fr, this message translates to:
  /// **'Après chaque manche, le plus petit score sort (à 2 joueurs : seulement à la dernière). Le dernier en lice gagne.'**
  String get formatEliminationHelpLong;

  /// No description provided for @roomTheme.
  ///
  /// In fr, this message translates to:
  /// **'Thème du jour'**
  String get roomTheme;

  /// No description provided for @roomThemeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories du thème rapportent le double de points. Choisis géo, prénoms ou nature pour pimenter la partie.'**
  String get roomThemeHelp;

  /// No description provided for @visibilityHelp.
  ///
  /// In fr, this message translates to:
  /// **'Public : tous les joueurs connectés sont prévenus et peuvent rejoindre d\'un tap, sans code. Privé : seuls ceux qui ont le code peuvent entrer.'**
  String get visibilityHelp;

  /// No description provided for @publicRoomLobbyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Salon public : visible par tous les joueurs connectés. Ils peuvent rejoindre sans code depuis « Salons ».'**
  String get publicRoomLobbyHelp;

  /// No description provided for @publicRoomInvite.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau salon public de {host}'**
  String publicRoomInvite(String host);

  /// No description provided for @joinPublicRoom.
  ///
  /// In fr, this message translates to:
  /// **'REJOINDRE'**
  String get joinPublicRoom;

  /// No description provided for @joinWithCodeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Pour un salon privé uniquement'**
  String get joinWithCodeHelp;

  /// No description provided for @difficultyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Facile = lettres courantes. Difficile = toutes les lettres, y compris K, W, X, Y, Z.'**
  String get difficultyHelp;

  /// No description provided for @roomTypeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Duel = 2 joueurs. Groupe = jusqu\'à 8. Plus on est nombreux, plus les points partagés baissent.'**
  String get roomTypeHelp;

  /// No description provided for @durationHelp.
  ///
  /// In fr, this message translates to:
  /// **'Temps pour remplir toutes les catégories. Plus de catégories ou orthographe stricte = durée minimum plus longue.'**
  String get durationHelp;

  /// No description provided for @themeNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get themeNone;

  /// No description provided for @themeGeography.
  ///
  /// In fr, this message translates to:
  /// **'Géo (×2 villes & pays)'**
  String get themeGeography;

  /// No description provided for @themeNames.
  ///
  /// In fr, this message translates to:
  /// **'Prénoms (×2)'**
  String get themeNames;

  /// No description provided for @themeNature.
  ///
  /// In fr, this message translates to:
  /// **'Nature (×2 animaux & fruits)'**
  String get themeNature;

  /// No description provided for @freezeUse.
  ///
  /// In fr, this message translates to:
  /// **'FREEZE ({count})'**
  String freezeUse(int count);

  /// No description provided for @freezeBuyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Acheter un Freeze'**
  String get freezeBuyTitle;

  /// No description provided for @freezeBuyHelp.
  ///
  /// In fr, this message translates to:
  /// **'Bloque un adversaire 10 secondes. Coût : {price} pièces.\nTu en as 1 gratuit par partie.'**
  String freezeBuyHelp(int price);

  /// No description provided for @freezeInfoHelp.
  ///
  /// In fr, this message translates to:
  /// **'Pendant la manche, gèle un adversaire 10 secondes : il ne peut pas valider. 1 Freeze gratuit par partie, puis 15 pièces pour en racheter.'**
  String get freezeInfoHelp;

  /// No description provided for @freezePickTarget.
  ///
  /// In fr, this message translates to:
  /// **'Qui geler ?'**
  String get freezePickTarget;

  /// No description provided for @freezeAlready.
  ///
  /// In fr, this message translates to:
  /// **'Déjà gelé'**
  String get freezeAlready;

  /// No description provided for @freezeYouAreFrozen.
  ///
  /// In fr, this message translates to:
  /// **'❄ Tu es gelé ! Attends un peu…'**
  String get freezeYouAreFrozen;

  /// No description provided for @lightningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Éclair !'**
  String get lightningTitle;

  /// No description provided for @lightningHelp.
  ///
  /// In fr, this message translates to:
  /// **'{category} en {letter} — {seconds}s'**
  String lightningHelp(String category, String letter, int seconds);

  /// No description provided for @lightningInfoHelp.
  ///
  /// In fr, this message translates to:
  /// **'Entre deux manches : un mini QCM de 10 secondes. La bonne réponse te donne +2 points bonus. Sois rapide !'**
  String get lightningInfoHelp;

  /// No description provided for @lightningHit.
  ///
  /// In fr, this message translates to:
  /// **'Bien joué ! +{points}'**
  String lightningHit(int points);

  /// No description provided for @lightningMiss.
  ///
  /// In fr, this message translates to:
  /// **'Raté !'**
  String get lightningMiss;

  /// No description provided for @chatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chat du salon'**
  String get chatTitle;

  /// No description provided for @chatHint.
  ///
  /// In fr, this message translates to:
  /// **'Écris un message…'**
  String get chatHint;

  /// No description provided for @chatUnlockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer les messages privés'**
  String get chatUnlockTitle;

  /// No description provided for @chatUnlockHelp.
  ///
  /// In fr, this message translates to:
  /// **'Écris en privé à n\'importe quel joueur de ce salon (personne d\'autre ne vous lit). Coût : {price} pièces, une fois pour ce salon.'**
  String chatUnlockHelp(int price);

  /// No description provided for @chatUnlockButton.
  ///
  /// In fr, this message translates to:
  /// **'PRIVÉ · {price}'**
  String chatUnlockButton(int price);

  /// No description provided for @chatInfoHelp.
  ///
  /// In fr, this message translates to:
  /// **'La discussion de groupe est gratuite et reste dans le salon, même après la partie. Tague un joueur en touchant son pseudo. Les messages privés se débloquent une fois avec des pièces.'**
  String get chatInfoHelp;

  /// No description provided for @reactionsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réactions'**
  String get reactionsTitle;

  /// No description provided for @reactionsInfoHelp.
  ///
  /// In fr, this message translates to:
  /// **'Envoie une réaction (feu, dodo, clap, surprise) pendant les résultats ou à la fin. Gratuit, sans modération.'**
  String get reactionsInfoHelp;

  /// No description provided for @wordReviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Revue des mots'**
  String get wordReviewTitle;

  /// No description provided for @wordReviewHelp.
  ///
  /// In fr, this message translates to:
  /// **'Après la partie, retrouve les mots trouvés (surtout les uniques ⭐) avec des infos : capitale, continent, régime…'**
  String get wordReviewHelp;

  /// No description provided for @salonTitleChampion.
  ///
  /// In fr, this message translates to:
  /// **'Champion'**
  String get salonTitleChampion;

  /// No description provided for @salonTitleSpeedster.
  ///
  /// In fr, this message translates to:
  /// **'Éclair'**
  String get salonTitleSpeedster;

  /// No description provided for @salonTitleRare.
  ///
  /// In fr, this message translates to:
  /// **'Chasseur de pépites'**
  String get salonTitleRare;

  /// No description provided for @salonTitleDictionary.
  ///
  /// In fr, this message translates to:
  /// **'Dictionnaire vivant'**
  String get salonTitleDictionary;

  /// No description provided for @salonTitlesHelp.
  ///
  /// In fr, this message translates to:
  /// **'À la fin, des titres fun sont donnés : champion, le plus rapide, celui qui trouve des mots rares, le plus grand vocabulaire.'**
  String get salonTitlesHelp;

  /// No description provided for @rematchVote.
  ///
  /// In fr, this message translates to:
  /// **'REVANCHE ({votes}/{need})'**
  String rematchVote(int votes, int need);

  /// No description provided for @rematchHelp.
  ///
  /// In fr, this message translates to:
  /// **'Vote pour rejouer. Quand la majorité des joueurs humains a voté, une nouvelle partie démarre avec les mêmes réglages.'**
  String get rematchHelp;

  /// No description provided for @bonusRound.
  ///
  /// In fr, this message translates to:
  /// **'MANCHE BONUS'**
  String get bonusRound;

  /// No description provided for @bonusRoundHelp.
  ///
  /// In fr, this message translates to:
  /// **'Une mini-manche surprise après le podium, sans mise. Pour ceux qui veulent encore une manche avant de partir.'**
  String get bonusRoundHelp;

  /// No description provided for @errorFrozen.
  ///
  /// In fr, this message translates to:
  /// **'Tu es gelé pour le moment !'**
  String get errorFrozen;

  /// No description provided for @errorNoFreezes.
  ///
  /// In fr, this message translates to:
  /// **'Plus de Freeze'**
  String get errorNoFreezes;

  /// No description provided for @errorChatLocked.
  ///
  /// In fr, this message translates to:
  /// **'Débloque le chat d\'abord'**
  String get errorChatLocked;

  /// No description provided for @comingSoonBadge.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt'**
  String get comingSoonBadge;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @settingsSound.
  ///
  /// In fr, this message translates to:
  /// **'Effets sonores'**
  String get settingsSound;

  /// No description provided for @settingsMusic.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get settingsMusic;

  /// No description provided for @settingsVibration.
  ///
  /// In fr, this message translates to:
  /// **'Vibrations'**
  String get settingsVibration;

  /// No description provided for @roundPoints.
  ///
  /// In fr, this message translates to:
  /// **'+{points}'**
  String roundPoints(int points);

  /// No description provided for @gameOverGreat.
  ///
  /// In fr, this message translates to:
  /// **'Incroyable !'**
  String get gameOverGreat;

  /// No description provided for @gameOverGood.
  ///
  /// In fr, this message translates to:
  /// **'Bien joué !'**
  String get gameOverGood;

  /// No description provided for @gameOverTry.
  ///
  /// In fr, this message translates to:
  /// **'Tu peux faire mieux !'**
  String get gameOverTry;

  /// No description provided for @modeQuickMatch.
  ///
  /// In fr, this message translates to:
  /// **'Partie rapide'**
  String get modeQuickMatch;

  /// No description provided for @modeRooms.
  ///
  /// In fr, this message translates to:
  /// **'Salons'**
  String get modeRooms;

  /// No description provided for @onlineCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} en ligne'**
  String onlineCount(int count);

  /// No description provided for @offlineShort.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offlineShort;

  /// No description provided for @nicknameTitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ton pseudo'**
  String get nicknameTitle;

  /// No description provided for @nicknameHint.
  ///
  /// In fr, this message translates to:
  /// **'Ton pseudo'**
  String get nicknameHint;

  /// No description provided for @nicknameConfirm.
  ///
  /// In fr, this message translates to:
  /// **'C\'EST PARTI !'**
  String get nicknameConfirm;

  /// No description provided for @roomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons'**
  String get roomsTitle;

  /// No description provided for @createRoom.
  ///
  /// In fr, this message translates to:
  /// **'CRÉER UNE SALLE'**
  String get createRoom;

  /// No description provided for @joinWithCode.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre avec un code'**
  String get joinWithCode;

  /// No description provided for @joinCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de la salle'**
  String get joinCodeTitle;

  /// No description provided for @join.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get join;

  /// No description provided for @publicRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salons ouverts'**
  String get publicRoomsTitle;

  /// No description provided for @noPublicRooms.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon ouvert pour l\'instant. Crée le tien !'**
  String get noPublicRooms;

  /// No description provided for @roomOf.
  ///
  /// In fr, this message translates to:
  /// **'Salle de {name}'**
  String roomOf(String name);

  /// No description provided for @roundsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} manches'**
  String roundsCount(int count);

  /// No description provided for @playersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count}/{max}'**
  String playersCount(int count, int max);

  /// No description provided for @createRoomTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle salle'**
  String get createRoomTitle;

  /// No description provided for @roomType.
  ///
  /// In fr, this message translates to:
  /// **'Type de partie'**
  String get roomType;

  /// No description provided for @roomTypeDuel.
  ///
  /// In fr, this message translates to:
  /// **'Duel'**
  String get roomTypeDuel;

  /// No description provided for @roomTypeGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe (8 max)'**
  String get roomTypeGroup;

  /// No description provided for @visibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get visibility;

  /// No description provided for @visibilityPublic.
  ///
  /// In fr, this message translates to:
  /// **'Publique'**
  String get visibilityPublic;

  /// No description provided for @visibilityPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Privée'**
  String get visibilityPrivate;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'CRÉER'**
  String get create;

  /// No description provided for @roomCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de la salle'**
  String get roomCode;

  /// No description provided for @copyCode.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In fr, this message translates to:
  /// **'Code copié !'**
  String get codeCopied;

  /// No description provided for @shareInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get shareInvite;

  /// No description provided for @inviteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins ma partie Letter Race ! Code : {code}'**
  String inviteMessage(String code);

  /// No description provided for @waitingForPlayers.
  ///
  /// In fr, this message translates to:
  /// **'En attente de joueurs…'**
  String get waitingForPlayers;

  /// No description provided for @readyButton.
  ///
  /// In fr, this message translates to:
  /// **'JE SUIS PRÊT !'**
  String get readyButton;

  /// No description provided for @notReadyButton.
  ///
  /// In fr, this message translates to:
  /// **'PAS ENCORE'**
  String get notReadyButton;

  /// No description provided for @readyHint.
  ///
  /// In fr, this message translates to:
  /// **'La partie démarre quand tout le monde est prêt (2 joueurs minimum).'**
  String get readyHint;

  /// No description provided for @quickStartsIn.
  ///
  /// In fr, this message translates to:
  /// **'Début dans {seconds} s'**
  String quickStartsIn(int seconds);

  /// No description provided for @searchingPlayers.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de joueurs…'**
  String get searchingPlayers;

  /// No description provided for @hostBadge.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get hostBadge;

  /// No description provided for @readyBadge.
  ///
  /// In fr, this message translates to:
  /// **'Prêt'**
  String get readyBadge;

  /// No description provided for @youBadge.
  ///
  /// In fr, this message translates to:
  /// **'Toi'**
  String get youBadge;

  /// No description provided for @answersSent.
  ///
  /// In fr, this message translates to:
  /// **'Réponses envoyées !'**
  String get answersSent;

  /// No description provided for @waitingOthers.
  ///
  /// In fr, this message translates to:
  /// **'En attente des autres joueurs…'**
  String get waitingOthers;

  /// No description provided for @spectating.
  ///
  /// In fr, this message translates to:
  /// **'Tu joueras dès la prochaine manche.'**
  String get spectating;

  /// No description provided for @yourAnswers.
  ///
  /// In fr, this message translates to:
  /// **'Tes réponses'**
  String get yourAnswers;

  /// No description provided for @leaderboard.
  ///
  /// In fr, this message translates to:
  /// **'Classement'**
  String get leaderboard;

  /// No description provided for @nextRoundIn.
  ///
  /// In fr, this message translates to:
  /// **'Manche suivante dans {seconds} s'**
  String nextRoundIn(int seconds);

  /// No description provided for @podiumTitle.
  ///
  /// In fr, this message translates to:
  /// **'PODIUM'**
  String get podiumTitle;

  /// No description provided for @leaveRoom.
  ///
  /// In fr, this message translates to:
  /// **'QUITTER'**
  String get leaveRoom;

  /// No description provided for @leaveRoomMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu vas quitter la salle.'**
  String get leaveRoomMessage;

  /// No description provided for @noticeHintUsed.
  ///
  /// In fr, this message translates to:
  /// **'{name} utilise un joker ({category})'**
  String noticeHintUsed(String name, String category);

  /// No description provided for @noticeJoined.
  ///
  /// In fr, this message translates to:
  /// **'{name} a rejoint la salle'**
  String noticeJoined(String name);

  /// No description provided for @noticeLeft.
  ///
  /// In fr, this message translates to:
  /// **'{name} a quitté la salle'**
  String noticeLeft(String name);

  /// No description provided for @noticeDisconnected.
  ///
  /// In fr, this message translates to:
  /// **'{name} s\'est déconnecté'**
  String noticeDisconnected(String name);

  /// No description provided for @noticeReconnected.
  ///
  /// In fr, this message translates to:
  /// **'{name} est de retour'**
  String noticeReconnected(String name);

  /// No description provided for @connectionLost.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue… reconnexion'**
  String get connectionLost;

  /// No description provided for @errorRoomNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Salle introuvable.'**
  String get errorRoomNotFound;

  /// No description provided for @errorRoomFull.
  ///
  /// In fr, this message translates to:
  /// **'Cette salle est complète.'**
  String get errorRoomFull;

  /// No description provided for @errorGameInProgress.
  ///
  /// In fr, this message translates to:
  /// **'La partie est déjà en cours.'**
  String get errorGameInProgress;

  /// No description provided for @opponents.
  ///
  /// In fr, this message translates to:
  /// **'Adversaires'**
  String get opponents;

  /// No description provided for @opponentsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get opponentsNone;

  /// No description provided for @botLevel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau des bots'**
  String get botLevel;

  /// No description provided for @addBot.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un bot'**
  String get addBot;

  /// No description provided for @noticeBotsJoined.
  ///
  /// In fr, this message translates to:
  /// **'Personne en ligne : des bots te rejoignent !'**
  String get noticeBotsJoined;

  /// No description provided for @errorNotHost.
  ///
  /// In fr, this message translates to:
  /// **'Seul l\'hôte peut faire ça.'**
  String get errorNotHost;

  /// No description provided for @botTag.
  ///
  /// In fr, this message translates to:
  /// **'Bot'**
  String get botTag;

  /// No description provided for @hintTitle.
  ///
  /// In fr, this message translates to:
  /// **'Joker : {category} en {letter}'**
  String hintTitle(String category, String letter);

  /// No description provided for @hintSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un seul de ces mots est juste !'**
  String get hintSubtitle;

  /// No description provided for @statusHintWrong.
  ///
  /// In fr, this message translates to:
  /// **'Mauvais choix'**
  String get statusHintWrong;

  /// No description provided for @statusAlreadyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Déjà utilisé dans ce monde'**
  String get statusAlreadyUsed;

  /// No description provided for @hintedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Joker'**
  String get hintedBadge;

  /// No description provided for @hintNoneLeft.
  ///
  /// In fr, this message translates to:
  /// **'Plus de joker pour cette partie.'**
  String get hintNoneLeft;

  /// No description provided for @hintUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Pas de joker possible ici.'**
  String get hintUnavailable;

  /// No description provided for @buyHintTitle.
  ///
  /// In fr, this message translates to:
  /// **'Joker en plus'**
  String get buyHintTitle;

  /// No description provided for @buyHintMessage.
  ///
  /// In fr, this message translates to:
  /// **'Acheter un joker pour {count} pièces ?'**
  String buyHintMessage(int count);

  /// No description provided for @buyHintConfirm.
  ///
  /// In fr, this message translates to:
  /// **'{count} pièces'**
  String buyHintConfirm(int count);

  /// No description provided for @buyInfoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Infos'**
  String get buyInfoTitle;

  /// No description provided for @buyInfoMessage.
  ///
  /// In fr, this message translates to:
  /// **'Dévoiler les infos pour {count} pièces ?'**
  String buyInfoMessage(int count);

  /// No description provided for @buyInfoConfirm.
  ///
  /// In fr, this message translates to:
  /// **'{count} pièces'**
  String buyInfoConfirm(int count);

  /// No description provided for @buyInfoButton.
  ///
  /// In fr, this message translates to:
  /// **'Infos · {count} pièces'**
  String buyInfoButton(int count);

  /// No description provided for @buyInfoFree.
  ///
  /// In fr, this message translates to:
  /// **'Infos'**
  String get buyInfoFree;

  /// No description provided for @notOnlineForPurchase.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour dépenser des pièces.'**
  String get notOnlineForPurchase;

  /// No description provided for @offlineModeNotice.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion : partie solo hors ligne'**
  String get offlineModeNotice;

  /// No description provided for @settingsGameKeyboard.
  ///
  /// In fr, this message translates to:
  /// **'Clavier du jeu'**
  String get settingsGameKeyboard;

  /// No description provided for @keyNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get keyNext;

  /// No description provided for @keySpace.
  ///
  /// In fr, this message translates to:
  /// **'espace'**
  String get keySpace;

  /// No description provided for @settingsVoice.
  ///
  /// In fr, this message translates to:
  /// **'Voix du présentateur'**
  String get settingsVoice;

  /// No description provided for @voiceYouWinRound1.
  ///
  /// In fr, this message translates to:
  /// **'Bravo {name}, tu remportes la manche !'**
  String voiceYouWinRound1(String name);

  /// No description provided for @voiceYouWinRound2.
  ///
  /// In fr, this message translates to:
  /// **'Excellent {name} ! Manche gagnée !'**
  String voiceYouWinRound2(String name);

  /// No description provided for @voiceOtherWinsRound1.
  ///
  /// In fr, this message translates to:
  /// **'{name} remporte la manche !'**
  String voiceOtherWinsRound1(String name);

  /// No description provided for @voiceOtherWinsRound2.
  ///
  /// In fr, this message translates to:
  /// **'Cette manche est pour {name} !'**
  String voiceOtherWinsRound2(String name);

  /// No description provided for @voiceEncourage1.
  ///
  /// In fr, this message translates to:
  /// **'Courage, tu vas te rattraper !'**
  String get voiceEncourage1;

  /// No description provided for @voiceEncourage2.
  ///
  /// In fr, this message translates to:
  /// **'Pas de panique, la prochaine est pour toi !'**
  String get voiceEncourage2;

  /// No description provided for @voiceEncourage3.
  ///
  /// In fr, this message translates to:
  /// **'Allez, on lâche rien !'**
  String get voiceEncourage3;

  /// No description provided for @voiceTie.
  ///
  /// In fr, this message translates to:
  /// **'Égalité sur cette manche ! Tout reste à jouer !'**
  String get voiceTie;

  /// No description provided for @voiceNobodyScored.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'a marqué ! Concentrez-vous, ça repart !'**
  String get voiceNobodyScored;

  /// No description provided for @voiceSoloGreat.
  ///
  /// In fr, this message translates to:
  /// **'Superbe ! {points} points !'**
  String voiceSoloGreat(int points);

  /// No description provided for @voiceSoloGood.
  ///
  /// In fr, this message translates to:
  /// **'Bien joué, {points} points !'**
  String voiceSoloGood(int points);

  /// No description provided for @voiceSoloLow.
  ///
  /// In fr, this message translates to:
  /// **'Allez, tu peux faire mieux à la prochaine !'**
  String get voiceSoloLow;

  /// No description provided for @voiceSoloZero.
  ///
  /// In fr, this message translates to:
  /// **'Aïe, aucun point ! Respire, tu vas y arriver !'**
  String get voiceSoloZero;

  /// No description provided for @voiceYouWinGame.
  ///
  /// In fr, this message translates to:
  /// **'Victoire ! Bravo {name}, tu gagnes la partie !'**
  String voiceYouWinGame(String name);

  /// No description provided for @voiceOtherWinsGame.
  ///
  /// In fr, this message translates to:
  /// **'{name} gagne la partie ! Bien joué à tous. Une revanche ?'**
  String voiceOtherWinsGame(String name);

  /// No description provided for @voiceSoloGameEnd.
  ///
  /// In fr, this message translates to:
  /// **'Partie terminée ! {points} points au total !'**
  String voiceSoloGameEnd(int points);

  /// No description provided for @dialogStay.
  ///
  /// In fr, this message translates to:
  /// **'RESTER'**
  String get dialogStay;

  /// No description provided for @roundLabel.
  ///
  /// In fr, this message translates to:
  /// **'MANCHE'**
  String get roundLabel;

  /// No description provided for @onlineLabel.
  ///
  /// In fr, this message translates to:
  /// **'EN LIGNE'**
  String get onlineLabel;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @languageAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get languageAuto;

  /// No description provided for @settingsGender.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get settingsGender;

  /// No description provided for @genderMale.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get genderOther;

  /// No description provided for @settingsMusicVolume.
  ///
  /// In fr, this message translates to:
  /// **'Volume musique'**
  String get settingsMusicVolume;

  /// No description provided for @onboardingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue !'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Régle ton expérience en quelques secondes.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingContinue.
  ///
  /// In fr, this message translates to:
  /// **'C\'EST PARTI !'**
  String get onboardingContinue;

  /// No description provided for @suggestionExample.
  ///
  /// In fr, this message translates to:
  /// **'Réponse possible : {answer}'**
  String suggestionExample(String answer);

  /// No description provided for @suggestionFoundBy.
  ///
  /// In fr, this message translates to:
  /// **'{name} a trouvé : {answer}'**
  String suggestionFoundBy(String name, String answer);

  /// No description provided for @coinsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 pièce} =1{1 pièce} other{{count} pièces}}'**
  String coinsCount(int count);

  /// No description provided for @coinsGained.
  ///
  /// In fr, this message translates to:
  /// **'+{count, plural, =1{1 pièce} other{{count} pièces}}'**
  String coinsGained(int count);

  /// No description provided for @roomKind.
  ///
  /// In fr, this message translates to:
  /// **'Salon'**
  String get roomKind;

  /// No description provided for @roomKindClassic.
  ///
  /// In fr, this message translates to:
  /// **'Classique'**
  String get roomKindClassic;

  /// No description provided for @roomKindBet.
  ///
  /// In fr, this message translates to:
  /// **'Paris'**
  String get roomKindBet;

  /// No description provided for @stake.
  ///
  /// In fr, this message translates to:
  /// **'Mise par joueur'**
  String get stake;

  /// No description provided for @stakeShort.
  ///
  /// In fr, this message translates to:
  /// **'Mise {count}'**
  String stakeShort(int count);

  /// No description provided for @potLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pot : {count}'**
  String potLabel(int count);

  /// No description provided for @betRules.
  ///
  /// In fr, this message translates to:
  /// **'Chaque joueur mise la même somme. Le premier rafle tout, le pot est partagé en cas d\'égalité. Pas de bots.'**
  String get betRules;

  /// No description provided for @yourCoins.
  ///
  /// In fr, this message translates to:
  /// **'Ton solde : {count}'**
  String yourCoins(int count);

  /// No description provided for @betWon.
  ///
  /// In fr, this message translates to:
  /// **'Tu rafles {count} pièces !'**
  String betWon(int count);

  /// No description provided for @betLost.
  ///
  /// In fr, this message translates to:
  /// **'Mise perdue : {count} pièces'**
  String betLost(int count);

  /// No description provided for @errorNotEnoughCoins.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez de pièces pour cette mise.'**
  String get errorNotEnoughCoins;

  /// No description provided for @errorBotsNotAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Pas de bots dans un salon de paris.'**
  String get errorBotsNotAllowed;

  /// No description provided for @avatarTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon avatar'**
  String get avatarTitle;

  /// No description provided for @avatarCamera.
  ///
  /// In fr, this message translates to:
  /// **'PHOTO'**
  String get avatarCamera;

  /// No description provided for @avatarGallery.
  ///
  /// In fr, this message translates to:
  /// **'GALERIE'**
  String get avatarGallery;

  /// No description provided for @avatarPhotoInfo.
  ///
  /// In fr, this message translates to:
  /// **'Ta photo est transformée en dessin avant d\'être montrée aux autres joueurs.'**
  String get avatarPhotoInfo;

  /// No description provided for @avatarCharacters.
  ///
  /// In fr, this message translates to:
  /// **'Personnages'**
  String get avatarCharacters;

  /// No description provided for @avatarUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Avatar mis à jour !'**
  String get avatarUpdated;

  /// No description provided for @errorInvalidImage.
  ///
  /// In fr, this message translates to:
  /// **'Cette image n\'a pas pu être lue.'**
  String get errorInvalidImage;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Image trop lourde.'**
  String get errorFileTooLarge;

  /// No description provided for @reportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler la photo ?'**
  String get reportTitle;

  /// No description provided for @reportMessage.
  ///
  /// In fr, this message translates to:
  /// **'La photo de {name} est retirée après plusieurs signalements.'**
  String reportMessage(String name);

  /// No description provided for @reportConfirm.
  ///
  /// In fr, this message translates to:
  /// **'SIGNALER'**
  String get reportConfirm;

  /// No description provided for @reportSent.
  ///
  /// In fr, this message translates to:
  /// **'Merci, signalement envoyé.'**
  String get reportSent;

  /// No description provided for @musicCredits.
  ///
  /// In fr, this message translates to:
  /// **'Musiques de Kevin MacLeod (incompetech.com), licence Creative Commons BY 4.0 : « Monkeys Spinning Monkeys », « Fluffing a Duck », « Carefree », « Pixel Peeker Polka », « Sneaky Snitch », « Investigations », « Run Amok », « Funkorama », « Itty Bitty 8 Bit », « Bit Quest ».'**
  String get musicCredits;

  /// No description provided for @shopTitle.
  ///
  /// In fr, this message translates to:
  /// **'Boutique'**
  String get shopTitle;

  /// No description provided for @shopCoinsLabel.
  ///
  /// In fr, this message translates to:
  /// **'pièces'**
  String get shopCoinsLabel;

  /// No description provided for @shopBonus.
  ///
  /// In fr, this message translates to:
  /// **'+{percent} %'**
  String shopBonus(int percent);

  /// No description provided for @shopBought.
  ///
  /// In fr, this message translates to:
  /// **'+{count} pièces, merci !'**
  String shopBought(int count);

  /// No description provided for @shopPending.
  ///
  /// In fr, this message translates to:
  /// **'Paiement en attente : tes pièces arriveront dès qu\'il sera confirmé.'**
  String get shopPending;

  /// No description provided for @shopInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Cet achat n\'a pas pu être validé.'**
  String get shopInvalid;

  /// No description provided for @shopStoreError.
  ///
  /// In fr, this message translates to:
  /// **'L\'achat n\'a pas abouti.'**
  String get shopStoreError;

  /// No description provided for @shopRetryLater.
  ///
  /// In fr, this message translates to:
  /// **'Achat reçu : tes pièces seront ajoutées dès que le serveur sera joignable.'**
  String get shopRetryLater;

  /// No description provided for @shopUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La boutique n\'est pas disponible sur cet appareil pour le moment.'**
  String get shopUnavailable;

  /// No description provided for @shopLegal.
  ///
  /// In fr, this message translates to:
  /// **'Paiement sécurisé par Google Play ou l\'App Store. Les pièces n\'ont aucune valeur monétaire : elles ne sont ni remboursables, ni échangeables, ni convertibles en argent.'**
  String get shopLegal;

  /// No description provided for @avatarPhotoNeedsConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connecte-toi pour utiliser une photo : elle est transformée en dessin sur le serveur.'**
  String get avatarPhotoNeedsConnection;

  /// No description provided for @avatarPickFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir l\'appareil photo ou la galerie. Vérifie les autorisations de l\'appli.'**
  String get avatarPickFailed;

  /// No description provided for @avatarSavedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Avatar choisi ! Il sera partagé dès que tu seras en ligne.'**
  String get avatarSavedOffline;

  /// No description provided for @credits.
  ///
  /// In fr, this message translates to:
  /// **'Crédits'**
  String get credits;

  /// No description provided for @levelUp.
  ///
  /// In fr, this message translates to:
  /// **'NIVEAU {level} !'**
  String levelUp(int level);

  /// No description provided for @levelLabel.
  ///
  /// In fr, this message translates to:
  /// **'Niveau {level}'**
  String levelLabel(int level);

  /// No description provided for @levelProgress.
  ///
  /// In fr, this message translates to:
  /// **'{xp} / {needed} points avant le niveau suivant'**
  String levelProgress(int xp, int needed);

  /// No description provided for @goalMinimum.
  ///
  /// In fr, this message translates to:
  /// **'Min. {points} pts'**
  String goalMinimum(int points);

  /// No description provided for @goalProgress.
  ///
  /// In fr, this message translates to:
  /// **'{score} / {target} pts'**
  String goalProgress(int score, int target);

  /// No description provided for @challengePassed.
  ///
  /// In fr, this message translates to:
  /// **'MINIMUM {points} PTS : RÉUSSI !'**
  String challengePassed(int points);

  /// No description provided for @challengeEliminated.
  ///
  /// In fr, this message translates to:
  /// **'ÉLIMINÉ ! Il fallait {points} pts'**
  String challengeEliminated(int points);

  /// No description provided for @careerProgressBanner.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {score} / {target} pts'**
  String careerProgressBanner(int score, int target);

  /// No description provided for @careerWon.
  ///
  /// In fr, this message translates to:
  /// **'Niveau {level} réussi !'**
  String careerWon(int level);

  /// No description provided for @careerLost.
  ///
  /// In fr, this message translates to:
  /// **'Niveau {level} raté'**
  String careerLost(int level);

  /// No description provided for @careerMessage.
  ///
  /// In fr, this message translates to:
  /// **'Objectif {target} pts · tu as marqué {score} pts'**
  String careerMessage(int target, int score);

  /// No description provided for @careerStarsInfo.
  ///
  /// In fr, this message translates to:
  /// **'Étoiles à {one}, {two} et {three} pts'**
  String careerStarsInfo(int one, int two, int three);

  /// No description provided for @nextLevel.
  ///
  /// In fr, this message translates to:
  /// **'NIVEAU SUIVANT'**
  String get nextLevel;

  /// No description provided for @replayLevel.
  ///
  /// In fr, this message translates to:
  /// **'REJOUER LE NIVEAU'**
  String get replayLevel;

  /// No description provided for @levelsMap.
  ///
  /// In fr, this message translates to:
  /// **'CARTE DES NIVEAUX'**
  String get levelsMap;

  /// No description provided for @eliminationChampion.
  ///
  /// In fr, this message translates to:
  /// **'Champion !'**
  String get eliminationChampion;

  /// No description provided for @eliminationOut.
  ///
  /// In fr, this message translates to:
  /// **'Éliminé !'**
  String get eliminationOut;

  /// No description provided for @eliminationMessage.
  ///
  /// In fr, this message translates to:
  /// **'Tu as tenu {rounds, plural, =0{0 manche} =1{1 manche} other{{rounds} manches}} sur {total}'**
  String eliminationMessage(int rounds, int total);

  /// No description provided for @eliminationRecord.
  ///
  /// In fr, this message translates to:
  /// **'Record : {rounds} manches'**
  String eliminationRecord(int rounds);

  /// No description provided for @eliminationNewRecord.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau record : {rounds} manches !'**
  String eliminationNewRecord(int rounds);

  /// No description provided for @careerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Carrière'**
  String get careerTitle;

  /// No description provided for @careerRulesIntro.
  ///
  /// In fr, this message translates to:
  /// **'60 niveaux de 5 manches, en 4 mondes de 15. Une étoile ouvre le niveau suivant.'**
  String get careerRulesIntro;

  /// No description provided for @careerRulesFromConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Au monde Débutant, les catégories montent : Ville et Pays, puis Animal, puis Fruit. À partir du Confirmé, les prénoms s\'ajoutent. Ensuite les lettres durcissent et l\'objectif de points grimpe.'**
  String get careerRulesFromConfirmed;

  /// No description provided for @careerRulesStars.
  ///
  /// In fr, this message translates to:
  /// **'1 étoile à l\'objectif, puis 2 et 3 étoiles en t\'approchant du score parfait.'**
  String get careerRulesStars;

  /// No description provided for @careerRulesBeginner.
  ///
  /// In fr, this message translates to:
  /// **'Lettres faciles, 60 puis 45 puis 30 secondes. Ville et Pays, puis Animal, puis Fruit.'**
  String get careerRulesBeginner;

  /// No description provided for @careerRulesConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Lettres normales. Les quatre catégories, puis un prénom féminin en plus.'**
  String get careerRulesConfirmed;

  /// No description provided for @careerRulesExpert.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les lettres, même les plus rares. Un prénom masculin en plus.'**
  String get careerRulesExpert;

  /// No description provided for @careerRulesMaster.
  ///
  /// In fr, this message translates to:
  /// **'Les six catégories, objectifs plus hauts. Il faut trouver de nouveaux mots.'**
  String get careerRulesMaster;

  /// No description provided for @careerRulesReuse.
  ///
  /// In fr, this message translates to:
  /// **'Dans le même monde, un mot déjà validé ne peut plus servir si la lettre revient.'**
  String get careerRulesReuse;

  /// No description provided for @gotIt.
  ///
  /// In fr, this message translates to:
  /// **'COMPRIS'**
  String get gotIt;

  /// No description provided for @worldBeginner.
  ///
  /// In fr, this message translates to:
  /// **'Débutant'**
  String get worldBeginner;

  /// No description provided for @worldConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmé'**
  String get worldConfirmed;

  /// No description provided for @worldExpert.
  ///
  /// In fr, this message translates to:
  /// **'Expert'**
  String get worldExpert;

  /// No description provided for @worldMaster.
  ///
  /// In fr, this message translates to:
  /// **'Maître'**
  String get worldMaster;

  /// No description provided for @levelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Niveau {level}'**
  String levelTitle(int level);

  /// No description provided for @levelGoal.
  ///
  /// In fr, this message translates to:
  /// **'Objectif : {target} points'**
  String levelGoal(int target);

  /// No description provided for @play.
  ///
  /// In fr, this message translates to:
  /// **'JOUER'**
  String get play;

  /// No description provided for @modeCareer.
  ///
  /// In fr, this message translates to:
  /// **'Carrière'**
  String get modeCareer;

  /// No description provided for @modeElimination.
  ///
  /// In fr, this message translates to:
  /// **'Éliminatoires'**
  String get modeElimination;

  /// No description provided for @modeFreeSolo.
  ///
  /// In fr, this message translates to:
  /// **'Solo libre'**
  String get modeFreeSolo;

  /// No description provided for @voiceChatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salon vocal'**
  String get voiceChatTitle;

  /// No description provided for @voiceChatHelp.
  ///
  /// In fr, this message translates to:
  /// **'Parlez pendant la partie. Coupez votre micro quand vous voulez. L\'hôte peut couper un micro, tous les micros, ou exclure quelqu\'un.'**
  String get voiceChatHelp;

  /// No description provided for @voiceJoin.
  ///
  /// In fr, this message translates to:
  /// **'REJOINDRE'**
  String get voiceJoin;

  /// No description provided for @voiceConnecting.
  ///
  /// In fr, this message translates to:
  /// **'CONNEXION…'**
  String get voiceConnecting;

  /// No description provided for @voiceMuteSelf.
  ///
  /// In fr, this message translates to:
  /// **'COUPER MON MICRO'**
  String get voiceMuteSelf;

  /// No description provided for @voiceUnmuteSelf.
  ///
  /// In fr, this message translates to:
  /// **'OUVRIR MON MICRO'**
  String get voiceUnmuteSelf;

  /// No description provided for @voiceMuteAll.
  ///
  /// In fr, this message translates to:
  /// **'COUPER TOUS LES MICROS'**
  String get voiceMuteAll;

  /// No description provided for @voiceUnmuteAll.
  ///
  /// In fr, this message translates to:
  /// **'RENDRE LES MICROS'**
  String get voiceUnmuteAll;

  /// No description provided for @voiceMutePlayer.
  ///
  /// In fr, this message translates to:
  /// **'Couper le micro'**
  String get voiceMutePlayer;

  /// No description provided for @voiceUnmutePlayer.
  ///
  /// In fr, this message translates to:
  /// **'Rendre le micro'**
  String get voiceUnmutePlayer;

  /// No description provided for @voiceExcludePlayer.
  ///
  /// In fr, this message translates to:
  /// **'Exclure du vocal'**
  String get voiceExcludePlayer;

  /// No description provided for @voiceHostMutedYou.
  ///
  /// In fr, this message translates to:
  /// **'L\'hôte a coupé ton micro.'**
  String get voiceHostMutedYou;

  /// No description provided for @voiceKickedNotice.
  ///
  /// In fr, this message translates to:
  /// **'L\'hôte t\'a exclu du salon vocal.'**
  String get voiceKickedNotice;

  /// No description provided for @voiceMutedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé'**
  String get voiceMutedBadge;

  /// No description provided for @voiceExcludedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Exclu du vocal'**
  String get voiceExcludedBadge;

  /// No description provided for @voiceHostBadge.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get voiceHostBadge;

  /// No description provided for @voiceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Vocal non configuré sur le serveur (Agora).'**
  String get voiceUnavailable;

  /// No description provided for @errorVoiceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Salon vocal indisponible.'**
  String get errorVoiceUnavailable;

  /// No description provided for @errorVoiceClosed.
  ///
  /// In fr, this message translates to:
  /// **'Le vocal n\'est pas encore ouvert (attente du début de partie).'**
  String get errorVoiceClosed;

  /// No description provided for @errorVoiceExcluded.
  ///
  /// In fr, this message translates to:
  /// **'Tu es exclu du salon vocal.'**
  String get errorVoiceExcluded;

  /// No description provided for @errorMicDenied.
  ///
  /// In fr, this message translates to:
  /// **'Autorise le micro pour parler.'**
  String get errorMicDenied;

  /// No description provided for @rulesButton.
  ///
  /// In fr, this message translates to:
  /// **'Règle'**
  String get rulesButton;

  /// No description provided for @eliminationRulesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Règle'**
  String get eliminationRulesTitle;

  /// No description provided for @eliminationRulesIntro.
  ///
  /// In fr, this message translates to:
  /// **'Lis la règle avant de régler ta compétition.'**
  String get eliminationRulesIntro;

  /// No description provided for @eliminationRules.
  ///
  /// In fr, this message translates to:
  /// **'Pas de solo : joue avec des amis, en duel, ou contre des bots. Toutes les catégories. À chaque manche, le plus petit score sort (à 2 joueurs : seulement à la dernière). Le dernier en lice remporte la compétition ({rounds} manches max) !'**
  String eliminationRules(int rounds);

  /// No description provided for @roundsRange.
  ///
  /// In fr, this message translates to:
  /// **'Manches {from} à {to}'**
  String roundsRange(int from, int to);

  /// No description provided for @eliminationBestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ton record'**
  String get eliminationBestTitle;

  /// No description provided for @eliminationNoRecord.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de record'**
  String get eliminationNoRecord;

  /// No description provided for @formatRounds.
  ///
  /// In fr, this message translates to:
  /// **'Par manches'**
  String get formatRounds;

  /// No description provided for @formatElimination.
  ///
  /// In fr, this message translates to:
  /// **'Éliminatoires'**
  String get formatElimination;

  /// No description provided for @formatRoundsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les manches sont jouées : le meilleur total gagne.'**
  String get formatRoundsHelp;

  /// No description provided for @formatEliminationHelp.
  ///
  /// In fr, this message translates to:
  /// **'À chaque manche, le plus petit score est éliminé (à 2 joueurs : seulement à la dernière manche). Le dernier en lice gagne.'**
  String get formatEliminationHelp;

  /// No description provided for @youAreEliminated.
  ///
  /// In fr, this message translates to:
  /// **'Tu es éliminé : regarde la fin de la partie !'**
  String get youAreEliminated;

  /// No description provided for @youAreOut.
  ///
  /// In fr, this message translates to:
  /// **'Tu es éliminé !'**
  String get youAreOut;

  /// No description provided for @playerIsOut.
  ///
  /// In fr, this message translates to:
  /// **'{name} est éliminé !'**
  String playerIsOut(String name);

  /// No description provided for @categoryFemaleName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom féminin'**
  String get categoryFemaleName;

  /// No description provided for @categoryMaleName.
  ///
  /// In fr, this message translates to:
  /// **'Prénom masculin'**
  String get categoryMaleName;

  /// No description provided for @manyCategoriesHint.
  ///
  /// In fr, this message translates to:
  /// **'{count} catégories ou plus : 45 secondes minimum par manche.'**
  String manyCategoriesHint(int count);

  /// No description provided for @strictSpelling.
  ///
  /// In fr, this message translates to:
  /// **'Orthographe stricte'**
  String get strictSpelling;

  /// No description provided for @strictSpellingHelp.
  ///
  /// In fr, this message translates to:
  /// **'Casse, accents et espaces doivent coller à la fiche. Manches d\'au moins 2 minutes.'**
  String get strictSpellingHelp;

  /// No description provided for @strictSpellingChip.
  ///
  /// In fr, this message translates to:
  /// **'Orthographe stricte'**
  String get strictSpellingChip;

  /// No description provided for @preparingGame.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de la partie…'**
  String get preparingGame;

  /// No description provided for @playAlone.
  ///
  /// In fr, this message translates to:
  /// **'JOUER SEUL'**
  String get playAlone;

  /// No description provided for @withFriends.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la compétition'**
  String get withFriends;

  /// No description provided for @withFriendsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Invite des amis (code), rejoins un salon, ou joue tout de suite contre des bots. Tu peux aussi ajouter des bots dans le lobby en attendant tes amis.'**
  String get withFriendsHelp;

  /// No description provided for @inviteFriends.
  ///
  /// In fr, this message translates to:
  /// **'INVITER DES AMIS'**
  String get inviteFriends;

  /// No description provided for @looksTitle.
  ///
  /// In fr, this message translates to:
  /// **'Boutique style'**
  String get looksTitle;

  /// No description provided for @looksSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Essaie un look, puis achète-le avec tes pièces.'**
  String get looksSubtitle;

  /// No description provided for @looksPreview.
  ///
  /// In fr, this message translates to:
  /// **'Ton aperçu'**
  String get looksPreview;

  /// No description provided for @looksPacks.
  ///
  /// In fr, this message translates to:
  /// **'Packs'**
  String get looksPacks;

  /// No description provided for @looksHair.
  ///
  /// In fr, this message translates to:
  /// **'Coiffures'**
  String get looksHair;

  /// No description provided for @looksHat.
  ///
  /// In fr, this message translates to:
  /// **'Chapeaux'**
  String get looksHat;

  /// No description provided for @looksFrame.
  ///
  /// In fr, this message translates to:
  /// **'Cadres'**
  String get looksFrame;

  /// No description provided for @looksName.
  ///
  /// In fr, this message translates to:
  /// **'Pseudos'**
  String get looksName;

  /// No description provided for @looksTiles.
  ///
  /// In fr, this message translates to:
  /// **'Tuiles'**
  String get looksTiles;

  /// No description provided for @looksVictory.
  ///
  /// In fr, this message translates to:
  /// **'Victoire'**
  String get looksVictory;

  /// No description provided for @looksPacksHint.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs styles assortis, moins cher en lot.'**
  String get looksPacksHint;

  /// No description provided for @looksHairHint.
  ///
  /// In fr, this message translates to:
  /// **'Change de coupe sans toucher à ton personnage.'**
  String get looksHairHint;

  /// No description provided for @looksHatHint.
  ///
  /// In fr, this message translates to:
  /// **'Couronnes, casquettes et chapeaux magiques.'**
  String get looksHatHint;

  /// No description provided for @looksFrameHint.
  ///
  /// In fr, this message translates to:
  /// **'Anneaux, ornements, flammes ou étoiles.'**
  String get looksFrameHint;

  /// No description provided for @looksNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Couleur, dégradé, contour ou badge devant le pseudo.'**
  String get looksNameHint;

  /// No description provided for @looksTilesHint.
  ///
  /// In fr, this message translates to:
  /// **'Couleurs et motifs des cases quand tu joues.'**
  String get looksTilesHint;

  /// No description provided for @looksVictoryHint.
  ///
  /// In fr, this message translates to:
  /// **'Confettis, étoiles, bulles ou pluie de lettres.'**
  String get looksVictoryHint;

  /// No description provided for @looksHairSpiky.
  ///
  /// In fr, this message translates to:
  /// **'Hérisson'**
  String get looksHairSpiky;

  /// No description provided for @looksHairBob.
  ///
  /// In fr, this message translates to:
  /// **'Carré rose'**
  String get looksHairBob;

  /// No description provided for @looksHairCurly.
  ///
  /// In fr, this message translates to:
  /// **'Boucles bleues'**
  String get looksHairCurly;

  /// No description provided for @looksHairBun.
  ///
  /// In fr, this message translates to:
  /// **'Chignon or'**
  String get looksHairBun;

  /// No description provided for @looksHatCrown.
  ///
  /// In fr, this message translates to:
  /// **'Couronne'**
  String get looksHatCrown;

  /// No description provided for @looksHatCap.
  ///
  /// In fr, this message translates to:
  /// **'Casquette'**
  String get looksHatCap;

  /// No description provided for @looksHatWizard.
  ///
  /// In fr, this message translates to:
  /// **'Chapeau mage'**
  String get looksHatWizard;

  /// No description provided for @looksHatParty.
  ///
  /// In fr, this message translates to:
  /// **'Fête'**
  String get looksHatParty;

  /// No description provided for @looksFrameOrnament.
  ///
  /// In fr, this message translates to:
  /// **'Ornement'**
  String get looksFrameOrnament;

  /// No description provided for @looksFrameFlames.
  ///
  /// In fr, this message translates to:
  /// **'Flammes'**
  String get looksFrameFlames;

  /// No description provided for @looksFrameStars.
  ///
  /// In fr, this message translates to:
  /// **'Étoiles'**
  String get looksFrameStars;

  /// No description provided for @looksNameGradient.
  ///
  /// In fr, this message translates to:
  /// **'Dégradé'**
  String get looksNameGradient;

  /// No description provided for @looksNameOutline.
  ///
  /// In fr, this message translates to:
  /// **'Contour'**
  String get looksNameOutline;

  /// No description provided for @looksNameBadge.
  ///
  /// In fr, this message translates to:
  /// **'Badge'**
  String get looksNameBadge;

  /// No description provided for @looksTilesStripes.
  ///
  /// In fr, this message translates to:
  /// **'Rayures'**
  String get looksTilesStripes;

  /// No description provided for @looksTilesDots.
  ///
  /// In fr, this message translates to:
  /// **'Pois'**
  String get looksTilesDots;

  /// No description provided for @looksTilesMetal.
  ///
  /// In fr, this message translates to:
  /// **'Métal'**
  String get looksTilesMetal;

  /// No description provided for @looksVictoryStars.
  ///
  /// In fr, this message translates to:
  /// **'Étoiles'**
  String get looksVictoryStars;

  /// No description provided for @looksVictoryBubbles.
  ///
  /// In fr, this message translates to:
  /// **'Bulles'**
  String get looksVictoryBubbles;

  /// No description provided for @looksVictoryLetters.
  ///
  /// In fr, this message translates to:
  /// **'Lettres'**
  String get looksVictoryLetters;

  /// No description provided for @looksPackOcean.
  ///
  /// In fr, this message translates to:
  /// **'Pack Océan'**
  String get looksPackOcean;

  /// No description provided for @looksPackCandy.
  ///
  /// In fr, this message translates to:
  /// **'Pack Bonbon'**
  String get looksPackCandy;

  /// No description provided for @looksPackRoyal.
  ///
  /// In fr, this message translates to:
  /// **'Pack Royal'**
  String get looksPackRoyal;

  /// No description provided for @looksPackContents.
  ///
  /// In fr, this message translates to:
  /// **'{count} styles'**
  String looksPackContents(int count);

  /// No description provided for @looksOwned.
  ///
  /// In fr, this message translates to:
  /// **'POSSEDÉ'**
  String get looksOwned;

  /// No description provided for @looksEquip.
  ///
  /// In fr, this message translates to:
  /// **'ÉQUIPER'**
  String get looksEquip;

  /// No description provided for @looksEquipped.
  ///
  /// In fr, this message translates to:
  /// **'ÉQUIPÉ'**
  String get looksEquipped;

  /// No description provided for @looksPrice.
  ///
  /// In fr, this message translates to:
  /// **'{count} pièces'**
  String looksPrice(int count);

  /// No description provided for @looksNotEnough.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez de pièces.'**
  String get looksNotEnough;

  /// No description provided for @looksGold.
  ///
  /// In fr, this message translates to:
  /// **'Or'**
  String get looksGold;

  /// No description provided for @looksPink.
  ///
  /// In fr, this message translates to:
  /// **'Rose'**
  String get looksPink;

  /// No description provided for @looksCyan.
  ///
  /// In fr, this message translates to:
  /// **'Cyan'**
  String get looksCyan;

  /// No description provided for @looksViolet.
  ///
  /// In fr, this message translates to:
  /// **'Violet'**
  String get looksViolet;

  /// No description provided for @looksOrange.
  ///
  /// In fr, this message translates to:
  /// **'Orange'**
  String get looksOrange;

  /// No description provided for @looksMint.
  ///
  /// In fr, this message translates to:
  /// **'Menthe'**
  String get looksMint;

  /// No description provided for @perksFreeCoins.
  ///
  /// In fr, this message translates to:
  /// **'Pièces gratuites'**
  String get perksFreeCoins;

  /// No description provided for @perksWatchInfo.
  ///
  /// In fr, this message translates to:
  /// **'Regarde une courte vidéo et gagne {coins} pièces. Encore {left} aujourd\'hui.'**
  String perksWatchInfo(int coins, int left);

  /// No description provided for @perksWatch.
  ///
  /// In fr, this message translates to:
  /// **'REGARDER (+{coins})'**
  String perksWatch(int coins);

  /// No description provided for @perksAdLimit.
  ///
  /// In fr, this message translates to:
  /// **'Plus de vidéo pour aujourd\'hui : reviens demain !'**
  String get perksAdLimit;

  /// No description provided for @perksAdPending.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo vue ! Tes pièces arrivent dans un instant.'**
  String get perksAdPending;

  /// No description provided for @perksNoAd.
  ///
  /// In fr, this message translates to:
  /// **'Pas de vidéo disponible pour le moment.'**
  String get perksNoAd;

  /// No description provided for @perksPassTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pass Letter Race'**
  String get perksPassTitle;

  /// No description provided for @perksPassNoAds.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pub entre les parties'**
  String get perksPassNoAds;

  /// No description provided for @perksPassDaily.
  ///
  /// In fr, this message translates to:
  /// **'{coins} pièces offertes chaque jour'**
  String perksPassDaily(int coins);

  /// No description provided for @perksPassHints.
  ///
  /// In fr, this message translates to:
  /// **'{hints} jokers en plus dans chaque partie'**
  String perksPassHints(int hints);

  /// No description provided for @perksPassActive.
  ///
  /// In fr, this message translates to:
  /// **'Pass actif jusqu\'au {date}'**
  String perksPassActive(String date);

  /// No description provided for @perksPassPrice.
  ///
  /// In fr, this message translates to:
  /// **'S\'ABONNER · {price} / mois'**
  String perksPassPrice(String price);

  /// No description provided for @perksClaimDaily.
  ///
  /// In fr, this message translates to:
  /// **'PRENDRE MES {coins} PIÈCES'**
  String perksClaimDaily(int coins);

  /// No description provided for @perksDailyTaken.
  ///
  /// In fr, this message translates to:
  /// **'BONUS DU JOUR PRIS'**
  String get perksDailyTaken;

  /// No description provided for @perksPassDone.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans le Pass !'**
  String get perksPassDone;

  /// No description provided for @perksRemoveAdsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sans pub'**
  String get perksRemoveAdsTitle;

  /// No description provided for @perksRemoveAdsInfo.
  ///
  /// In fr, this message translates to:
  /// **'Plus aucune pub entre les parties, pour toujours. Les vidéos pour gagner des pièces restent possibles.'**
  String get perksRemoveAdsInfo;

  /// No description provided for @perksRemoveAdsOwned.
  ///
  /// In fr, this message translates to:
  /// **'Sans pub : activé'**
  String get perksRemoveAdsOwned;

  /// No description provided for @perksRemoveAdsDone.
  ///
  /// In fr, this message translates to:
  /// **'C\'est fini les pubs, merci !'**
  String get perksRemoveAdsDone;

  /// No description provided for @shopUnavailableShort.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible'**
  String get shopUnavailableShort;

  /// No description provided for @roomHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Salon {code}'**
  String roomHistoryTitle(String code);

  /// No description provided for @historyGames.
  ///
  /// In fr, this message translates to:
  /// **'Parties'**
  String get historyGames;

  /// No description provided for @historyGroup.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get historyGroup;

  /// No description provided for @historyPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get historyPrivate;

  /// No description provided for @historyUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Historique indisponible pour le moment.'**
  String get historyUnavailable;

  /// No description provided for @historyNoGames.
  ///
  /// In fr, this message translates to:
  /// **'Aucune partie terminée dans ce salon pour l\'instant.'**
  String get historyNoGames;

  /// No description provided for @historyNoMessages.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'a encore écrit dans le groupe.'**
  String get historyNoMessages;

  /// No description provided for @historyNoPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation privée. Ouvre la discussion du salon, puis « Privé », pour écrire à un joueur.'**
  String get historyNoPrivate;

  /// No description provided for @privateChatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Écris ton premier message à {name}.'**
  String privateChatEmpty(String name);

  /// No description provided for @privateChatJoinRoom.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins le salon pour répondre.'**
  String get privateChatJoinRoom;

  /// No description provided for @privateChatUnlock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer les messages privés ({price} pièces)'**
  String privateChatUnlock(int price);

  /// No description provided for @privateChatHint.
  ///
  /// In fr, this message translates to:
  /// **'Message à {name}'**
  String privateChatHint(String name);

  /// No description provided for @myRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes salons'**
  String get myRoomsTitle;

  /// No description provided for @allPublicRoomsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tous les salons publics'**
  String get allPublicRoomsTitle;

  /// No description provided for @savedRoomInfo.
  ///
  /// In fr, this message translates to:
  /// **'{members} joueurs · {date}'**
  String savedRoomInfo(int members, String date);

  /// No description provided for @savedRoomOpen.
  ///
  /// In fr, this message translates to:
  /// **'{count} dedans'**
  String savedRoomOpen(int count);

  /// No description provided for @savedRoomClosed.
  ///
  /// In fr, this message translates to:
  /// **'Fermé'**
  String get savedRoomClosed;

  /// No description provided for @roomChatButton.
  ///
  /// In fr, this message translates to:
  /// **'DISCUSSION'**
  String get roomChatButton;

  /// No description provided for @roomHistoryButton.
  ///
  /// In fr, this message translates to:
  /// **'HISTORIQUE'**
  String get roomHistoryButton;

  /// No description provided for @chatPrivateButton.
  ///
  /// In fr, this message translates to:
  /// **'Privé'**
  String get chatPrivateButton;

  /// No description provided for @chatPrivatePick.
  ///
  /// In fr, this message translates to:
  /// **'À qui veux-tu écrire ?'**
  String get chatPrivatePick;

  /// No description provided for @chatMentionedBy.
  ///
  /// In fr, this message translates to:
  /// **'{name} t\'a tagué dans la discussion'**
  String chatMentionedBy(String name);

  /// No description provided for @chatTagHint.
  ///
  /// In fr, this message translates to:
  /// **'Touche un pseudo pour le taguer (@pseudo).'**
  String get chatTagHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
