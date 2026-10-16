import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_icon.dart';

/// Bandeau doré d'un salon de paris : mise, pot, ou résultat du pari.
class BetBanner extends StatelessWidget {
  const BetBanner({super.key, required this.text, this.highlight = true});

  final String text;

  /// Faux pour une mise perdue : bandeau plus discret.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.yellow : AppColors.white;
    return Container(
      key: const Key('bet_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 1 : 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppColors.depthOf(AppColors.yellow),
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GameIcon(GameIconKind.coin, size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: fredoka(
                size: 16,
                weight: FontWeight.w700,
                color: highlight ? AppColors.ink : AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
