import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../chrono/chrono_hub_screen.dart';
import '../game/widgets/labels.dart';
import '../mots/mots_hub_screen.dart';
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

/// « Salons » : choisir le jeu.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) => GameChoiceScreen(
    title: AppLocalizations.of(context).gamesTitle,
    onLetters: (context) async {
      final ready = await readyForOnline(context);
      if (!ready || !context.mounted) return;
      await Navigator.of(context)
          .push(PopRoute(builder: (_) => const RoomsScreen()));
    },
    onIq: (context) => Navigator.of(context)
        .push(PopRoute(builder: (_) => IqHubScreen(apiClient: apiClient))),
    onChrono: (context) => Navigator.of(context).push(
      PopRoute(
        builder: (_) => ChronoHubScreen(apiClient: apiClient, rooms: true),
      ),
    ),
    onMots: (context) => Navigator.of(context).push(
      PopRoute(
        builder: (_) => MotsHubScreen(apiClient: apiClient, rooms: true),
      ),
    ),
  );
}

/// Choix du jeu : grille 2×2 (Géo, QI, Chrono, Mot & Sens).
class GameChoiceScreen extends StatelessWidget {
  const GameChoiceScreen({
    super.key,
    required this.title,
    required this.onLetters,
    required this.onIq,
    this.onChrono,
    this.onMots,
  });

  final String title;
  final Future<void> Function(BuildContext context) onLetters;
  final Future<void> Function(BuildContext context) onIq;
  final Future<void> Function(BuildContext context)? onChrono;
  final Future<void> Function(BuildContext context)? onMots;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: title,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 520,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        children: [
                          Expanded(
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
                                        size: 40,
                                        color: AppColors.sage,
                                      ),
                                      color: AppColors.sage,
                                      onTap: () => onLetters(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: BounceIn(
                                    from: 0.7,
                                    delay: const Duration(milliseconds: 80),
                                    child: _GameCard(
                                      key: const Key('game_iq'),
                                      title: l10n.gameIqTitle,
                                      tag: l10n.gameIqTag,
                                      icon: const Icon(
                                        Icons.psychology_rounded,
                                        size: 44,
                                        color: AppColors.sandDeep,
                                      ),
                                      color: AppColors.sandDeep,
                                      onTap: () => onIq(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: BounceIn(
                                    from: 0.7,
                                    delay: const Duration(milliseconds: 120),
                                    child: _GameCard(
                                      key: const Key('game_chrono'),
                                      title: l10n.gameChronoTitle,
                                      tag: l10n.gameChronoTag,
                                      icon: const Icon(
                                        Icons.hourglass_top_rounded,
                                        size: 44,
                                        color: AppColors.ochre,
                                      ),
                                      color: AppColors.ochre,
                                      onTap: () => onChrono?.call(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: BounceIn(
                                    from: 0.7,
                                    delay: const Duration(milliseconds: 160),
                                    child: _GameCard(
                                      key: const Key('game_mots'),
                                      title: l10n.gameMotsTitle,
                                      tag: l10n.gameMotsTag,
                                      icon: const Icon(
                                        Icons.menu_book_rounded,
                                        size: 44,
                                        color: AppColors.clay,
                                      ),
                                      color: AppColors.dustyRose,
                                      onTap: () => onMots?.call(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
    final light = color.computeLuminance() > 0.35;
    final ink = light ? AppColors.inkRetro : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
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
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(color).withValues(alpha: 0.6),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: icon,
                ),
              ),
            ),
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: gameFont(size: 16, color: ink, height: 1.1),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: light ? 0.55 : 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fredoka(size: 11, weight: FontWeight.w600, color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
