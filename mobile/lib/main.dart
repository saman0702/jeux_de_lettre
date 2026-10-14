import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/audio/game_audio.dart';
import 'core/feedback/game_feedback.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final feedback = GameFeedback(
    audio: await AudioplayersGameAudio.create(),
    settings: await AppSettings.load(),
  );
  runApp(LetterBattleApp(feedback: feedback));
}

class LetterBattleApp extends StatefulWidget {
  const LetterBattleApp({
    super.key,
    this.home = const HomeScreen(),
    this.feedback,
  });

  final Widget home;

  /// Defaults to a silent instance (tests).
  final GameFeedback? feedback;

  @override
  State<LetterBattleApp> createState() => _LetterBattleAppState();
}

class _LetterBattleAppState extends State<LetterBattleApp>
    with WidgetsBindingObserver {
  late final GameFeedback _feedback = widget.feedback ?? GameFeedback.silent();

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
  }

  @override
  Widget build(BuildContext context) {
    return GameFeedbackScope(
      feedback: _feedback,
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
    );
  }
}
