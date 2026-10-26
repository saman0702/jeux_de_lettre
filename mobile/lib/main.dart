import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/audio/game_audio.dart';
import 'core/feedback/game_feedback.dart';
import 'core/feedback/vibrator.dart';
import 'core/voice/announcer.dart';
import 'core/network/realtime_client.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/game/offline/offline_dictionary.dart';
import 'features/home/app_splash.dart';
import 'features/online/online_controller.dart';
import 'core/network/api_client.dart';
import 'features/avatar/avatar_sync.dart';
import 'features/perks/ads_service.dart';
import 'features/perks/perks_controller.dart';
import 'features/shop/coin_store.dart';
import 'features/shop/shop_controller.dart';
import 'features/wallet/coin_counter.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final feedback = GameFeedback(
    audio: await AudioplayersGameAudio.create(),
    settings: settings,
    vibrator: await DeviceVibrator.create(),
    announcer: DeviceAnnouncer(),
  );
  final online = OnlineController(
    RealtimeClient(
      clientId: settings.clientId,
      nickname: settings.nickname ?? 'Joueur',
      language: appLanguage(settings),
      country: settings.country,
    ),
  );
  // Chacun répond dans la langue de son appli : le serveur doit la connaître,
  // ainsi que le pays d'origine (drapeau vu par les autres).
  settings.addListener(
    () => online.client.updateIdentity(
      language: appLanguage(settings),
      country: settings.country,
    ),
  );
  // Une seule connexion pour toute l'appli : compteur en ligne, salons et
  // parties.
  online.client.connect();
  online.onLook = (look) {
    // applyLook appelle déjà onLook : on ne mémorise que tuiles / confettis.
    settings.setStyles(tiles: look.tiles, victory: look.victory);
  };
  AvatarSync(settings: settings, online: online, api: ApiClient());
  // Écoute le store dès le démarrage : un achat interrompu est repris.
  final shop = ShopController(
    store: DeviceCoinStore(),
    api: ApiClient(),
    clientId: settings.clientId,
    onWallet: online.applyWallet,
  )..start();
  // Pubs, « Sans pub » et Pass : seulement les options activées dans le .env
  // du serveur.
  final perks = PerksController(
    api: ApiClient(),
    online: online,
    ads: AdMobAdsService(),
    storage: await PrefsPerksStorage.load(),
  );
  unawaited(perks.load());
  // Prêt pour les parties solo hors ligne, sans retarder le démarrage.
  OfflineDictionary.load();
  runApp(
    LetterBattleApp(
      feedback: feedback,
      online: online,
      shop: shop,
      perks: perks,
    ),
  );
}

/// Langue réellement affichée : celle choisie, sinon celle du téléphone si
/// l'appli la parle (français), sinon l'anglais.
String appLanguage(AppSettings settings) {
  final code =
      settings.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
  return code == 'fr' ? 'fr' : 'en';
}

class LetterBattleApp extends StatefulWidget {
  const LetterBattleApp({
    super.key,
    this.home = const AppSplash(),
    this.feedback,
    this.online,
    this.shop,
    this.perks,
  });

  final Widget home;

  /// Par défaut, une instance silencieuse (tests).
  final GameFeedback? feedback;

  /// Par défaut, un contrôleur qui ne se connecte jamais (tests).
  final OnlineController? online;

  /// Par défaut, une boutique sans store (tests).
  final ShopController? shop;

  /// Par défaut, aucune pub ni option (tests).
  final PerksController? perks;

  @override
  State<LetterBattleApp> createState() => _LetterBattleAppState();
}

class _LetterBattleAppState extends State<LetterBattleApp>
    with WidgetsBindingObserver {
  late final GameFeedback _feedback = widget.feedback ?? GameFeedback.silent();
  late final OnlineController _online =
      widget.online ??
      OnlineController(
        RealtimeClient(
          clientId: _feedback.settings.clientId,
          nickname: 'Joueur',
        ),
      );
  late final ShopController _shop =
      widget.shop ??
      ShopController(
        store: UnavailableCoinStore(),
        api: ApiClient(),
        clientId: _online.clientId,
        onWallet: _online.applyWallet,
      );
  late final PerksController _perks =
      widget.perks ?? PerksController(api: ApiClient(), online: _online);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pas de musique quand l'appli est en arrière-plan.
    _feedback.appInForeground = state == AppLifecycleState.resumed;
    // Les téléphones peuvent couper la socket en arrière-plan : on se
    // reconnecte au retour.
    if (state == AppLifecycleState.resumed &&
        widget.online != null &&
        !_online.isOnline) {
      _online.client.connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFeedbackScope(
      feedback: _feedback,
      child: OnlineScope(
        controller: _online,
        child: ShopScope(
          controller: _shop,
          child: PerksScope(
            controller: _perks,
            child: ListenableBuilder(
              listenable: _feedback.settings,
              builder: (context, _) => MaterialApp(
                locale: _feedback.settings.languageCode == null
                    ? null
                    : Locale(_feedback.settings.languageCode!),
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                // La police agrandie du téléphone faisait déborder cadres et
                // boutons : on la suit, mais pas au-delà de 10 %.
                builder: (context, child) => MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.1,
                  child:
                      CoinGainOverlay(child: child ?? const SizedBox.shrink()),
                ),
                home: widget.home,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
