import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Police d'emojis utilisée quand Fredoka n'a pas le caractère. Les téléphones
/// utilisent de toute façon leur police d'emojis système ; la nommer permet
/// aussi de les afficher dans les captures.
const emojiFallback = ['NotoColorEmoji'];

/// Style de texte du jeu. Les textes en gras (titres, boutons, scores, mots
/// joués) prennent la police de jeu Lilita One ; les petits textes restent en
/// Fredoka, plus lisible en petit. Fredoka est une police variable : sa
/// graisse passe par l'axe `wght`.
TextStyle fredoka({
  double size = 16,
  FontWeight weight = FontWeight.w500,
  Color color = AppColors.ink,
  double? height,
  List<Shadow>? shadows,
}) => weight.value >= 700
    ? gameFont(size: size, color: color, height: height, shadows: shadows)
    : TextStyle(
        fontFamily: 'Fredoka',
        fontFamilyFallback: emojiFallback,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color,
        height: height,
        shadows: shadows,
      );

/// Police de jeu (une seule graisse, déjà très épaisse).
TextStyle gameFont({
  double size = 16,
  Color color = AppColors.ink,
  double? height,
  List<Shadow>? shadows,
  double letterSpacing = 0.3,
}) => TextStyle(
  fontFamily: 'LilitaOne',
  fontFamilyFallback: const ['Fredoka', ...emojiFallback],
  fontSize: size,
  color: color,
  height: height,
  shadows: shadows,
  letterSpacing: letterSpacing,
);

/// Ombre portée douce pour le texte blanc sur le fond violet.
const textShadow = [
  Shadow(color: Color(0x55000000), offset: Offset(0, 3), blurRadius: 0),
];

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      primary: AppColors.purple,
      secondary: AppColors.yellow,
      error: AppColors.red,
      surface: AppColors.white,
    );

    TextStyle base(double size, FontWeight weight) =>
        fredoka(size: size, weight: weight);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Fredoka',
      fontFamilyFallback: emojiFallback,
      scaffoldBackgroundColor: AppColors.purple,
      textTheme: TextTheme(
        displayLarge: base(56, FontWeight.w700),
        displayMedium: base(44, FontWeight.w700),
        displaySmall: base(36, FontWeight.w700),
        headlineMedium: base(28, FontWeight.w700),
        headlineSmall: base(24, FontWeight.w700),
        titleLarge: base(22, FontWeight.w600),
        titleMedium: base(18, FontWeight.w600),
        titleSmall: base(15, FontWeight.w600),
        bodyLarge: base(17, FontWeight.w500),
        bodyMedium: base(15, FontWeight.w500),
        bodySmall: base(13, FontWeight.w500),
        labelLarge: base(15, FontWeight.w600),
        labelMedium: base(13, FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: fredoka(color: AppColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.grey,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
