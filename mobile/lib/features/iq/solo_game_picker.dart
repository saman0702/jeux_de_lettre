import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../online/data/room_models.dart';

/// En tête de « Solo libre » : Géographie & Nature ou QI.
class SoloGamePicker extends StatelessWidget {
  const SoloGamePicker({
    super.key,
    required this.current,
    required this.onPick,
  });

  final RoomGame current;
  final ValueChanged<RoomGame> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OptionSection(
      index: 0,
      title: l10n.gamesTitle,
      icon: GameIconKind.trophy,
      color: AppColors.purpleLight,
      child: PillSelector<RoomGame>(
        key: const Key('solo_game_picker'),
        options: RoomGame.values,
        isSelected: (g) => g == current,
        label: (g) =>
            g == RoomGame.iq ? l10n.gameIqTitle : l10n.gameLettersTitle,
        icon: (g) =>
            g == RoomGame.iq ? GameIconKind.hint : GameIconKind.country,
        onTap: (g) {
          if (g != current) onPick(g);
        },
      ),
    );
  }
}

/// Passe d'un écran de réglages à l'autre sans animation, comme un onglet.
void switchSoloScreen(BuildContext context, Widget screen) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => screen,
    ),
  );
}
