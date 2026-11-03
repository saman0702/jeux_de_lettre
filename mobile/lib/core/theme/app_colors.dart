import 'package:flutter/material.dart';

/// Palette de Mind Race : couleurs vives « bonbon » sur fond violet,
/// plus une gamme sable / rétro pour Chrono, Mot & Sens et la grille Solo.
abstract final class AppColors {
  static const purple = Color(0xFF6C3CE1);
  static const purpleDeep = Color(0xFF4421A8);
  static const purpleLight = Color(0xFF9466FF);
  static const ink = Color(0xFF2D1B69);
  static const inkSoft = Color(0xFF6E61A0);
  static const cloud = Color(0xFFF6F1FF);
  static const white = Colors.white;

  static const yellow = Color(0xFFFFC93C);
  static const orange = Color(0xFFFF8A3D);
  static const pink = Color(0xFFFF5FA2);
  static const cyan = Color(0xFF3CC8FF);
  static const green = Color(0xFF2ECC71);
  static const red = Color(0xFFFF5A5F);
  static const grey = Color(0xFFB9B1D6);

  /// Gamme sable / rétro (QCM, tuiles Solo libre).
  static const sand = Color(0xFFE8D4B0);
  static const sandDeep = Color(0xFFC4A06A);
  static const ochre = Color(0xFFD9A441);
  static const clay = Color(0xFFC97B5A);
  static const sage = Color(0xFF8FA37A);
  static const dustyRose = Color(0xFFC9897B);
  static const parchment = Color(0xFFF3E6CF);
  static const inkRetro = Color(0xFF3F2E1E);

  /// Quatre teintes pour les choix QCM (grille 2×2).
  static const List<Color> sandChoices = [ochre, clay, sage, dustyRose];

  /// Teinte plus sombre servant de relief 3D sous les boutons bonbon et les
  /// tuiles.
  static Color depthOf(Color color) => HSLColor.fromColor(color)
      .withLightness((HSLColor.fromColor(color).lightness - 0.18).clamp(0, 1))
      .toColor();
}
