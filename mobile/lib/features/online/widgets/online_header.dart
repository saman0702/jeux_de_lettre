import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/outlined_text.dart';

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
          // Titre cerné de violet foncé : lisible quand le contenu défile
          // dessous.
          Expanded(
            child: OutlinedText(
              title,
              strokeWidth: 5,
              style: fredoka(
                size: 26,
                weight: FontWeight.w700,
                color: AppColors.white,
                shadows: textShadow,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
