import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../audio/game_audio.dart';
import '../feedback/game_feedback.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'candy_button.dart';
import 'game_icon.dart';

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
                  margin: const EdgeInsets.only(top: 58),
                  padding: const EdgeInsets.fromLTRB(20, 54, 20, 18),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Color.lerp(accent, Colors.white, 0.55)!,
                      width: 4,
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
                              height: 54,
                              fontSize: 18,
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
                              height: 54,
                              fontSize: 18,
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
                  top: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.white, width: 3),
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
                        size: 19,
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
                      width: 62,
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.yellow,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.depthOf(AppColors.yellow),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GameIcon(icon, size: 34, color: AppColors.ink),
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
