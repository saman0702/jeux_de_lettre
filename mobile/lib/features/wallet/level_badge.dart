import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Pastille du niveau du joueur, posée sur le bord de son avatar.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 20});

  final int level;
  final double size;

  /// Couleur selon le palier : la pastille change en progressant.
  static Color colorOf(int level) => switch (level) {
    < 5 => AppColors.green,
    < 10 => AppColors.cyan,
    < 20 => AppColors.purpleLight,
    < 35 => AppColors.pink,
    _ => AppColors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(level);
    return Container(
      key: const Key('level_badge'),
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: size * 0.22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: AppColors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(color),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$level',
        style: gameFont(
          size: size * 0.6,
          color: AppColors.white,
          height: 1,
          shadows: textShadow,
        ),
      ),
    );
  }
}
