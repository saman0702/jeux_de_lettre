import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'candy_button.dart';
import 'game_icon.dart';

/// Boîte d'info façon jeu : un seul bouton.
Future<void> showGameInfo(
  BuildContext context, {
  required GameIconKind icon,
  required String title,
  required String message,
  required String okLabel,
  Color accent = AppColors.cyan,
}) async {
  final feedback = GameFeedbackScope.of(context);
  feedback.play(Sfx.reveal);
  feedback.haptic(Haptic.light);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppColors.ink.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (context, _, _) => _GameInfo(
      icon: icon,
      title: title,
      message: message,
      okLabel: okLabel,
      accent: accent,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      ),
    ),
  );
}

/// Petite pastille « i » : ouvre [showGameInfo] au tap.
class InfoTip extends StatelessWidget {
  const InfoTip({
    super.key,
    required this.title,
    required this.message,
    required this.okLabel,
    this.icon = GameIconKind.flag,
    this.accent = AppColors.cyan,
    this.color = AppColors.inkSoft,
    this.size = 22,
  });

  final String title;
  final String message;
  final String okLabel;
  final GameIconKind icon;
  final Color accent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final feedback = GameFeedbackScope.of(context);
          feedback.play(Sfx.tap);
          feedback.haptic(Haptic.light);
          showGameInfo(
            context,
            icon: icon,
            title: title,
            message: message,
            okLabel: okLabel,
            accent: accent,
          );
        },
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
          ),
          child: Text(
            'i',
            style: fredoka(
              size: size * 0.55,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _GameInfo extends StatelessWidget {
  const _GameInfo({
    required this.icon,
    required this.title,
    required this.message,
    required this.okLabel,
    required this.accent,
  });

  final GameIconKind icon;
  final String title;
  final String message;
  final String okLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 48),
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Color.lerp(accent, Colors.white, 0.55)!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(AppColors.purple),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 17,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CandyButton(
                        label: okLabel,
                        color: accent,
                        textColor: AppColors.white,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.white, width: 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(accent, Colors.white, 0.3)!,
                          accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.depthOf(accent),
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      title.toUpperCase(),
                      style: fredoka(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.white,
                        shadows: textShadow,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  child: BounceIn(
                    delay: const Duration(milliseconds: 120),
                    from: 0,
                    child: Container(
                      width: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.depthOf(AppColors.yellow),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GameIcon(icon, size: 28, color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Boîte oui/non façon jeu : elle apparaît avec un rebond, a un titre en
/// bandeau, une grande icône animée et des boutons bonbon. Renvoie vrai quand
/// le joueur confirme.
Future<bool> showGameConfirm(
  BuildContext context, {
  required GameIconKind icon,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  Color accent = AppColors.red,
}) async {
  final feedback = GameFeedbackScope.of(context);
  feedback.play(Sfx.reveal);
  feedback.haptic(Haptic.medium);
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: AppColors.ink.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, _) => _GameConfirm(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      accent: accent,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      ),
    ),
  );
  return result ?? false;
}

class _GameConfirm extends StatelessWidget {
  const _GameConfirm({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.accent,
  });

  final GameIconKind icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          type: MaterialType.transparency,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // La boîte elle-même.
                Container(
                  margin: const EdgeInsets.only(top: 48),
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Color.lerp(accent, Colors.white, 0.55)!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(AppColors.purple),
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 18,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: CandyButton(
                              key: const Key('dialog_cancel'),
                              label: cancelLabel,
                              color: AppColors.green,
                              textColor: AppColors.white,
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CandyButton(
                              key: const Key('dialog_confirm'),
                              label: confirmLabel,
                              color: accent,
                              textColor: AppColors.white,
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Titre en bandeau sur le bord supérieur.
                Positioned(
                  top: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.white, width: 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(accent, Colors.white, 0.3)!,
                          accent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.depthOf(accent),
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      title.toUpperCase(),
                      style: fredoka(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.white,
                        shadows: textShadow,
                      ),
                    ),
                  ),
                ),
                // Grand badge avec l'icône.
                Positioned(
                  top: -6,
                  child: BounceIn(
                    delay: const Duration(milliseconds: 120),
                    from: 0,
                    child: Container(
                      width: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.depthOf(AppColors.yellow),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GameIcon(icon, size: 28, color: AppColors.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
