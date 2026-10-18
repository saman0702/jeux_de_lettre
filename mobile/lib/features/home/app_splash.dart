import 'package:flutter/material.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/letter_race_logo.dart';
import '../../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Splash : même logo texte (tuiles LETTER / RACE) que l'accueil.
class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> {
  static const _hold = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_hold, () {
      if (!mounted) return;
      final settings = GameFeedbackScope.of(context).settings;
      final next = settings.onboardingDone
          ? const HomeScreen()
          : const OnboardingScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => next,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LetterRaceLogo(animate: false),
              const SizedBox(height: 20),
              Text(
                l10n.tagline,
                textAlign: TextAlign.center,
                style: fredoka(
                  size: 17,
                  color: AppColors.white,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
