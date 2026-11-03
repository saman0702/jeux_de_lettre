import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_background.dart';
import '../../l10n/app_localizations.dart';
import '../online/data/room_models.dart';
import '../quiz/quiz_hub_screen.dart';
import '../quiz/quiz_rooms_hub_screen.dart';
import 'chrono_bank.dart';

/// Entrée Chrono : solo (QuizHub) ou salons (QuizRoomsHub).
class ChronoHubScreen extends StatelessWidget {
  const ChronoHubScreen({super.key, this.apiClient, this.rooms = false});

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
        game: RoomGame.chrono,
        title: l10n.gameChronoTitle,
        soloTitle: l10n.chronoSoloTitle,
        theme: theme,
        accent: AppColors.ochre,
        questions: chronoBank(),
        apiClient: apiClient,
      );
    }
    return QuizHubScreen(
      title: l10n.gameChronoTitle,
      soloTitle: l10n.chronoSoloTitle,
      theme: theme,
      accent: AppColors.ochre,
      questions: chronoBank(),
      soloKey: const Key('chrono_solo'),
      game: 'chrono',
      apiClient: apiClient,
    );
  }
}
