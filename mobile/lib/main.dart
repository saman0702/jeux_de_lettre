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
import 'features/home/home_screen.dart';
import 'features/online/online_controller.dart';
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
    ),
  );
  // Une seule connexion pour toute l'appli : compteur en ligne, salons et
  // parties.
  online.client.connect();
  // Prêt pour les parties solo hors ligne, sans retarder le démarrage.
  OfflineDictionary.load();
  runApp(LetterBattleApp(feedback: feedback, online: online));
}

class LetterBattleApp extends StatefulWidget {
  const LetterBattleApp({
    super.key,
    this.home = const HomeScreen(),
    this.feedback,
    this.online,
  });

  final Widget home;

  /// Par défaut, une instance silencieuse (tests).
  final GameFeedback? feedback;

  /// Par défaut, un contrôleur qui ne se connecte jamais (tests).
  final OnlineController? online;

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
        child: ListenableBuilder(
          listenable: _feedback.settings,
          builder: (context, _) => MaterialApp(
            locale: _feedback.settings.languageCode == null
                ? null
                : Locale(_feedback.settings.languageCode!),
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) =>
                CoinGainOverlay(child: child ?? const SizedBox.shrink()),
            home: widget.home,
          ),
        ),
      ),
    );
  }
}
