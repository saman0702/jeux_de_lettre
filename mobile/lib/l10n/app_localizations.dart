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
  /// **'Letter Battle'**
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
