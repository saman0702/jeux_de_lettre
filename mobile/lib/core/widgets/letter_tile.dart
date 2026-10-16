import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Tuile-lettre façon jeu de plateau, avec une tranche en 3D.
class LetterTile extends StatelessWidget {
  const LetterTile({
    super.key,
    required this.letter,
    this.size = 44,
    this.color = AppColors.yellow,
    this.textColor = AppColors.ink,
    this.textKey,
  });

  final String letter;
  final double size;
  final Color color;
  final Color textColor;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final depth = size * 0.1;
    return SizedBox(
      width: size,
      height: size + depth,
      child: Stack(
        children: [
          Positioned(
            top: depth,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.depthOf(color),
                borderRadius: BorderRadius.circular(size * 0.22),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  key: textKey,
                  style: fredoka(
                    size: size * 0.62,
                    weight: FontWeight.w700,
                    color: textColor,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
