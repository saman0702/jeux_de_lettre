import 'package:flutter/material.dart';

import '../../home/country_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../data/room_models.dart';
import '../../shop/look_styles.dart';
import 'player_avatar.dart';

/// Rangée des joueurs de la salle pendant la partie : avec qui on joue, leur
/// score, et qui a déjà répondu à la manche.
class PlayersStrip extends StatelessWidget {
  const PlayersStrip({
    super.key,
    required this.room,
    required this.myId,
    this.showProgress = true,
    this.forceFinishedIds = const {},
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final RoomState room;
  final String myId;

  /// Affiche « écrit encore / a répondu » (pendant la manche).
  final bool showProgress;

  /// Ids déjà soumis côté client (avant ack serveur), ex. après Finish.
  final Set<String> forceFinishedIds;

  /// Marges de la liste (aucune quand elle partage sa ligne avec le chrono).
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final players = room.ranking;
    return SizedBox(
      key: const Key('players_strip'),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: players.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = players[i];
          return _PlayerChip(
            player: p,
            isMe: p.clientId == myId,
            showProgress: showProgress,
            finished: p.finished || forceFinishedIds.contains(p.clientId),
          );
        },
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({
    required this.player,
    required this.isMe,
    required this.showProgress,
    required this.finished,
  });

  final RoomPlayer player;
  final bool isMe;
  final bool showProgress;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final out = player.eliminated || !player.connected;
    final GameIconKind? status = !showProgress || out || !player.playing
        ? null
        : finished
        ? GameIconKind.check
        : GameIconKind.writing;

    return Opacity(
      opacity: out ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.yellow
              : AppColors.purpleDeep.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.white, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar.of(player, size: 28),
            const SizedBox(width: 6),
            if (player.country != null) ...[
              CountryBadge(country: player.country, width: 14),
              const SizedBox(width: 4),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 84),
                  child: StyledNickname(
                    isMe ? l10n.youBadge : player.nickname,
                    styleId: player.nameStyle,
                    size: 12,
                    fallbackColor: isMe ? AppColors.ink : AppColors.white,
                  ),
                ),
                Text(
                  l10n.pointsShort(player.score),
                  style: fredoka(
                    size: 11,
                    weight: FontWeight.w600,
                    color: isMe
                        ? AppColors.ink.withValues(alpha: 0.75)
                        : AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(width: 6),
              GameIcon(
                status,
                size: 15,
                color: status == GameIconKind.check
                    ? AppColors.green
                    : (isMe ? AppColors.ink : AppColors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
