import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';

/// Bouton retour + titre blanc en haut des écrans en ligne.
class OnlineHeader extends StatelessWidget {
  const OnlineHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: onBack),
          const SizedBox(width: 12),
          // Titre blanc cerné de violet foncé, comme dans les jeux : il reste
          // lisible quand le contenu défile dessous.
          Expanded(
            child: Stack(
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fredoka(size: 26, weight: FontWeight.w700).copyWith(
                    color: null,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 5
                      ..strokeJoin = StrokeJoin.round
                      ..color = AppColors.ink,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fredoka(
                    size: 26,
                    weight: FontWeight.w700,
                    color: AppColors.white,
                    shadows: textShadow,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
