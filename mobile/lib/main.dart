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
  // One connection for the whole app: online count, rooms and games.
  online.client.connect();
  // Ready for offline solo games without delaying the start.
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

  /// Defaults to a silent instance (tests).
  final GameFeedback? feedback;

  /// Defaults to a controller that never connects (tests).
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
    // No music while the app is in the background.
    _feedback.appInForeground = state == AppLifecycleState.resumed;
    // Phones may kill the socket in the background: reconnect on return.
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
        child: MaterialApp(
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
          home: widget.home,
        ),
      ),
    );
  }
}
