import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'outlined_text.dart';

/// Logo Mind Race (initiales MR) — même style que l'icône app :
/// MR violet, petites lettres blanches, contour jaune.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 1,
    this.framing = true,
  });

  /// Échelle globale (1 ≈ largeur confortable sur téléphone).
  final double size;

  /// Cadre blanc + bordure orange (comme l'icône). Désactiver si déjà
  /// sur fond clair.
  final bool framing;

  @override
  Widget build(BuildContext context) {
    final lr = 118.0 * size;
    final deco = 34.0 * size;
    final caption = 18.0 * size;

    final mark = Semantics(
      label: 'Mind Race',
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
                    _big('M', lr),
                    SizedBox(width: 4 * size),
                    _big('R', lr),
                  ],
                ),
                _deco('E', deco, const Offset(-78, -28), -0.25, AppColors.green),
                _deco('B', deco, const Offset(-72, 8), 0.18, AppColors.purple),
                _deco('S', deco, const Offset(-48, 42), -0.12, AppColors.orange),
                _deco('J', deco, const Offset(52, -22), 0.22, AppColors.red),
                _deco('A', deco, const Offset(68, 36), -0.18, AppColors.yellow),
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
              color: framing
                  ? AppColors.purpleDeep
                  : AppColors.white.withValues(alpha: 0.92),
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (!framing) return mark;

    return Container(
      padding: EdgeInsets.fromLTRB(22 * size, 18 * size, 22 * size, 16 * size),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(36 * size),
        border: Border.all(color: AppColors.yellow, width: 3 * size),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            offset: Offset(0, 8 * size),
            blurRadius: 0,
          ),
        ],
      ),
      child: mark,
    );
  }

  Widget _big(String letter, double fontSize) => OutlinedText(
    letter,
    style: gameFont(
      size: fontSize,
      color: AppColors.purple,
      height: 1,
      shadows: [
        Shadow(
          color: AppColors.ink.withValues(alpha: 0.45),
          offset: Offset(3 * size, 4 * size),
          blurRadius: 0,
        ),
      ],
    ),
    outline: AppColors.yellow,
    strokeWidth: 2.5 * size,
  );

  Widget _deco(
    String letter,
    double fontSize,
    Offset offset,
    double angle,
    Color color,
  ) {
    return Transform.translate(
      offset: Offset(offset.dx * size, offset.dy * size),
      child: Transform.rotate(
        angle: angle * math.pi,
        child: OutlinedText(
          letter,
          style: gameFont(size: fontSize, color: color, height: 1),
          outline: AppColors.yellow,
          strokeWidth: 1.5 * size,
        ),
      ),
    );
  }
}
