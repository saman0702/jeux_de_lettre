import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'outlined_text.dart';

/// Logo Letter Race dessiné (police Lilita), net à toutes les densités —
/// contrairement à un PNG agrandi sur le splash natif.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 1});

  /// Échelle globale (1 ≈ largeur confortable sur téléphone).
  final double size;

  @override
  Widget build(BuildContext context) {
    final lr = 118.0 * size;
    final deco = 34.0 * size;
    final caption = 18.0 * size;

    return Semantics(
      label: 'Letter Race',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 220 * size,
            height: 150 * size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _big('L', lr),
                    SizedBox(width: 4 * size),
                    _big('R', lr),
                  ],
                ),
                _deco('E', deco, const Offset(-78, -28), -0.25),
                _deco('B', deco, const Offset(-72, 8), 0.18),
                _deco('S', deco, const Offset(-48, 42), -0.12),
                _deco('J', deco, const Offset(52, -22), 0.22),
                _deco('A', deco, const Offset(68, 36), -0.18),
              ],
            ),
          ),
          Container(
            width: 120 * size,
            height: 2.5 * size,
            margin: EdgeInsets.only(bottom: 8 * size),
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Course de lettres',
            textAlign: TextAlign.center,
            style: fredoka(
              size: caption,
              color: AppColors.white.withValues(alpha: 0.92),
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _big(String letter, double fontSize) => OutlinedText(
    letter,
    style: gameFont(
      size: fontSize,
      color: AppColors.white,
      height: 1,
      shadows: [
        Shadow(
          color: AppColors.ink.withValues(alpha: 0.55),
          offset: Offset(4 * size, 5 * size),
          blurRadius: 0,
        ),
      ],
    ),
    outline: AppColors.yellow,
    strokeWidth: 5 * size,
  );

  Widget _deco(String letter, double fontSize, Offset offset, double angle) {
    return Transform.translate(
      offset: Offset(offset.dx * size, offset.dy * size),
      child: Transform.rotate(
        angle: angle * math.pi,
        child: OutlinedText(
          letter,
          style: gameFont(size: fontSize, color: AppColors.purpleDeep, height: 1),
          outline: AppColors.yellow,
          strokeWidth: 2.5 * size,
        ),
      ),
    );
  }
}
