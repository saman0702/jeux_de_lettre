import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../widgets/labels.dart';
import '../../../core/widgets/game_icon.dart';

const _optionColors = [
  AppColors.yellow,
  AppColors.cyan,
  AppColors.pink,
  AppColors.orange,
];

/// Les quatre propositions du joker ; renvoie celle choisie, ou null si on
/// ferme.
Future<String?> showHintPicker(
  BuildContext context, {
  required Category category,
  required String letter,
  required List<String> options,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GameIconBadge(
                  GameIconKind.hint,
                  color: AppColors.yellow,
                  size: 52,
                ),
                const SizedBox(width: 10),
                GameIconBadge(category.icon, color: category.color, size: 52),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.hintTitle(category.label(l10n), letter),
              textAlign: TextAlign.center,
              style: fredoka(size: 22, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.hintSubtitle,
              textAlign: TextAlign.center,
              style: fredoka(size: 15, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 18),
            for (final (i, option) in options.indexed) ...[
              BounceIn(
                delay: Duration(milliseconds: 70 * i),
                from: 0.5,
                child: CandyButton(
                  key: Key('hint_option_$i'),
                  label: option,
                  color: _optionColors[i % _optionColors.length],
                  height: 56,
                  fontSize: 20,
                  onPressed: () => Navigator.pop(context, option),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ),
  );
}
