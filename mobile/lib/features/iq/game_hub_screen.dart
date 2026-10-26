import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/floating_bars_layout.dart';
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

/// « Salons » : choisir le jeu — Géographie & Nature (le Petit Bac) ou QI.
class GameHubScreen extends StatelessWidget {
  const GameHubScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: l10n.gamesTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
            children: [
              const SizedBox(height: 12),
              BounceIn(
                from: 0.7,
                child: _GameCard(
                  key: const Key('game_letters'),
                  title: l10n.gameLettersTitle,
                  info: l10n.gameLettersInfo,
                  icon: GameIconKind.country,
                  color: AppColors.green,
                  onTap: () async {
                    final ready = await readyForOnline(context);
                    if (!ready || !context.mounted) return;
                    await Navigator.of(context)
                        .push(PopRoute(builder: (_) => const RoomsScreen()));
                  },
                ),
              ),
              const SizedBox(height: 12),
              BounceIn(
                from: 0.7,
                delay: const Duration(milliseconds: 120),
                child: _GameCard(
                  key: const Key('game_iq'),
                  title: l10n.gameIqTitle,
                  info: l10n.gameIqInfo,
                  icon: GameIconKind.hint,
                  color: AppColors.purpleLight,
                  onTap: () => Navigator.of(context).push(
                    PopRoute(builder: (_) => IqHubScreen(apiClient: apiClient)),
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

class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.title,
    required this.info,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String info;
  final GameIconKind icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > 0.3;
    final ink = light ? AppColors.ink : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, AppColors.white, 0.25)!, color],
          ),
          border: Border.all(color: AppColors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(color),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: GameIcon(icon, size: 28, color: AppColors.depthOf(color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: gameFont(size: 19, color: ink)),
                  const SizedBox(height: 2),
                  Text(
                    info,
                    style: fredoka(size: 13, color: ink.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ink, size: 26),
          ],
        ),
      ),
    );
  }
}
