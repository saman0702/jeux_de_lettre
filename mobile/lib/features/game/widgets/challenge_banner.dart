import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';

/// Bandeau d'objectif : vert quand c'est réussi, rouge à l'élimination, jaune
/// pour une simple information.
class ChallengeBanner extends StatelessWidget {
  const ChallengeBanner({super.key, required this.text, this.success});

  final String text;

  /// true : réussi ; false : raté ; null : information.
  final bool? success;

  @override
  Widget build(BuildContext context) {
    final (color, icon, ink) = switch (success) {
      true => (AppColors.green, GameIconKind.check, AppColors.white),
      false => (AppColors.red, GameIconKind.warning, AppColors.white),
      null => (AppColors.yellow, GameIconKind.flag, AppColors.ink),
    };
    return Container(
      key: const Key('challenge_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(color),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameIcon(icon, size: 20, color: ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: gameFont(
                size: 15,
                color: ink,
                shadows: ink == AppColors.white ? textShadow : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
