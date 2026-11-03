import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_background.dart';
import '../../l10n/app_localizations.dart';
import '../online/data/room_models.dart';
import '../quiz/quiz_hub_screen.dart';
import '../quiz/quiz_rooms_hub_screen.dart';
import 'mots_bank.dart';

/// Entrée Mot & Sens : solo (QuizHub) ou salons (QuizRoomsHub).
class MotsHubScreen extends StatelessWidget {
  const MotsHubScreen({super.key, this.apiClient, this.rooms = false});

  final ApiClient? apiClient;

  /// true = hub salons (créer / rejoindre / bots).
  final bool rooms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Fond lettres + palette sable historique.
    const theme = BackgroundTheme.letters;
    if (rooms) {
      return QuizRoomsHubScreen(
        game: RoomGame.mots,
        title: l10n.gameMotsTitle,
        soloTitle: l10n.motsSoloTitle,
        theme: theme,
        accent: AppColors.clay,
        questions: motsBank(),
        apiClient: apiClient,
      );
    }
    return QuizHubScreen(
      title: l10n.gameMotsTitle,
      soloTitle: l10n.motsSoloTitle,
      theme: theme,
      accent: AppColors.clay,
      questions: motsBank(),
      soloKey: const Key('mots_solo'),
      game: 'mots',
      apiClient: apiClient,
    );
  }
}
