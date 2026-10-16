import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';

/// Boîte de réglage façon jeu : panneau blanc à bordure colorée en relief,
/// avec un bandeau titre centré à cheval sur le bord du haut (icône animée +
/// titre). Les options sont centrées dessous.
class OptionSection extends StatelessWidget {
  const OptionSection({
    super.key,
    required this.index,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  /// Position dans la liste, pour l'apparition décalée.
  final int index;
  final String title;
  final GameIconKind icon;

  /// Couleur de la bordure et du bandeau.
  final Color color;
  final Widget child;

  /// Hauteur du bandeau qui dépasse au-dessus de la boîte.
  static const _bannerOverlap = 15.0;

  @override
  Widget build(BuildContext context) {
    final depth = AppColors.depthOf(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BounceIn(
        delay: Duration(milliseconds: 60 * index),
        from: 0.85,
        slideY: 0.3,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: _bannerOverlap),
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 13),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(color: depth, offset: const Offset(0, 5)),
                ],
              ),
              child: Center(child: child),
            ),
            // Bandeau titre.
            Container(
              padding: const EdgeInsets.fromLTRB(10, 4, 16, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.white, width: 2.5),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, AppColors.white, 0.25)!, color],
                ),
                boxShadow: [
                  BoxShadow(color: depth, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameIcon(icon, size: 20, color: AppColors.white),
                  const SizedBox(width: 6),
                  Text(
                    title.toUpperCase(),
                    style: fredoka(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                      shadows: textShadow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
