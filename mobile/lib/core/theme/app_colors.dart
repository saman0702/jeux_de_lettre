import 'package:flutter/material.dart';

/// Letter Battle palette: bright "candy" colours on a purple background.
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

  /// Darker shade used as the 3D "depth" under candy buttons and tiles.
  static Color depthOf(Color color) => HSLColor.fromColor(color)
      .withLightness((HSLColor.fromColor(color).lightness - 0.18).clamp(0, 1))
      .toColor();
}
