import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_dialog.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../l10n/app_localizations.dart';

/// Bouton retour / quitter + titre blanc en haut des écrans en ligne.
class OnlineHeader extends StatelessWidget {
  const OnlineHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.help,
    this.helpTitle,
    this.helpIcon = GameIconKind.flag,
    this.helpLabel,
    this.quitStyle = false,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  /// Notice d'aide : libellé visible (ex. « Règle ») à côté du titre.
  final String? help;
  final String? helpTitle;
  final GameIconKind helpIcon;
  final String? helpLabel;

  /// Pendant une manche : icône « quitter » (croix rouge) au lieu de retour.
  final bool quitStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: quitStyle ? Icons.close_rounded : Icons.arrow_back_rounded,
            tooltip: quitStyle ? l10n.quit : null,
            color: quitStyle ? AppColors.red : AppColors.white,
            iconColor: quitStyle ? AppColors.white : AppColors.purple,
            size: 40,
            onPressed: onBack,
          ),
          const SizedBox(width: 12),
          // Titre cerné de violet foncé : lisible quand le contenu défile
          // dessous.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: OutlinedText(
                    title,
                    strokeWidth: 3.5,
                    style: fredoka(
                      size: 22,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                      shadows: textShadow,
                    ),
                  ),
                ),
                if (help != null) ...[
                  const SizedBox(width: 8),
                  _RulesChip(
                    label: helpLabel ?? l10n.rulesButton,
                    onTap: () {
                      final feedback = GameFeedbackScope.of(context);
                      feedback.play(Sfx.tap);
                      feedback.haptic(Haptic.light);
                      showGameInfo(
                        context,
                        icon: helpIcon,
                        title: helpTitle ?? title,
                        message: help!,
                        okLabel: l10n.gotIt,
                        accent: AppColors.pink,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Pastille « Règle » alignée sur le titre.
class _RulesChip extends StatelessWidget {
  const _RulesChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: fredoka(
              size: 13,
              weight: FontWeight.w800,
              color: AppColors.white,
              shadows: textShadow,
            ),
          ),
        ),
      ),
    );
  }
}
