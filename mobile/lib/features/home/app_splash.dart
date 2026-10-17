import 'package:flutter/material.dart';

import '../../core/widgets/brand_mark.dart';
import '../../core/widgets/game_background.dart';
import 'home_screen.dart';

/// Splash Flutter : même fond animé que l'app + logo dessiné (jamais flou).
/// Remplace le bitmap du splash natif dès la première frame.
class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> {
  static const _hold = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_hold, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GameBackground(
        child: Center(child: BrandMark()),
      ),
    );
  }
}
