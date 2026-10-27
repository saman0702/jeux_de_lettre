import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/labels.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_header.dart';
import 'iq_hub_screen.dart';

/// Les modes en ligne demandent une connexion et un pseudo.
Future<bool> readyForOnline(BuildContext context) async {
  final online = OnlineScope.of(context);
  if (!online.isOnline) {
    online.client.connect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage(AppLocalizations.of(context), 'network_error'),
        ),
      ),
    );
    return false;
  }
  return ensureNickname(context);
}

/// « Salons » : choisir le jeu — Géographie & Nature (le Petit Bac) ou QI,
/// deux grandes tuiles côte à côte.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: l10n.gamesTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: BounceIn(
                            from: 0.7,
                            child: _GameCard(
                              key: const Key('game_letters'),
                              title: l10n.gameLettersTitle,
                              tag: l10n.gameLettersTag,
                              icon: const GameIcon(
                                GameIconKind.country,
                                size: 48,
                                color: AppColors.green,
                              ),
                              color: AppColors.green,
                              onTap: () async {
                                final ready = await readyForOnline(context);
                                if (!ready || !context.mounted) return;
                                await Navigator.of(context).push(
                                  PopRoute(builder: (_) => const RoomsScreen()),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: BounceIn(
                            from: 0.7,
                            delay: const Duration(milliseconds: 120),
                            child: _GameCard(
                              key: const Key('game_iq'),
                              title: l10n.gameIqTitle,
                              tag: l10n.gameIqTag,
                              icon: const Icon(
                                Icons.psychology_rounded,
                                size: 52,
                                color: AppColors.purple,
                              ),
                              color: AppColors.purpleLight,
                              onTap: () => Navigator.of(context).push(
                                PopRoute(
                                  builder: (_) =>
                                      IqHubScreen(apiClient: apiClient),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile d'un jeu : grosse icône, nom, et une étiquette de quelques mots.
class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.title,
    required this.tag,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String tag;
  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > 0.3;
    final ink = light ? AppColors.ink : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(color, AppColors.white, 0.3)!, color],
            ),
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.depthOf(color),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.depthOf(color)
                              .withValues(alpha: 0.6),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: icon,
                  ),
                ),
              ),
              // Deux lignes réservées au nom : les icônes restent alignées.
              SizedBox(
                height: 42,
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: gameFont(size: 18, color: ink, height: 1.1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: light ? 0.55 : 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  textAlign: TextAlign.center,
                  style: fredoka(size: 12, weight: FontWeight.w600, color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
