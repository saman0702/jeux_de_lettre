import 'dart:async';

import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../animations/victory/confetti.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/voice/announcements.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../l10n/app_localizations.dart';
import '../data/room_models.dart';
import '../../wallet/bet_banner.dart';
import 'player_avatar.dart';
import '../../../core/widgets/game_icon.dart';

/// Fin de partie : podium avec médailles, confettis, puis rejouer ou quitter.
class PodiumView extends StatefulWidget {
  const PodiumView({
    super.key,
    required this.ranking,
    required this.myId,
    required this.onPlayAgain,
    required this.onLeave,
    this.stake = 0,
    this.winnings = const {},
  });

  final List<RoomPlayer> ranking;

  /// Salon de paris : mise de chaque joueur et gains des vainqueurs.
  final int stake;
  final Map<String, int> winnings;
  final String myId;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeave;

  @override
  State<PodiumView> createState() => _PodiumViewState();
}

class _PodiumViewState extends State<PodiumView> {
  Timer? _voice;

  @override
  void dispose() {
    _voice?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final feedback = GameFeedbackScope.of(context);
      feedback.play(Sfx.victory);
      feedback.haptic(Haptic.heavy);
      final winner = widget.ranking.first;
      final line = Announcements(AppLocalizations.of(context)).roomGameOver(
        winnerId: winner.clientId,
        winnerName: winner.nickname,
        me: widget.myId,
      );
      final language = Localizations.localeOf(context).languageCode;
      _voice = Timer(
        const Duration(milliseconds: 1400),
        () => feedback.announce(line, language),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ranking = widget.ranking;
    final rest = ranking.length > 3 ? ranking.sublist(3) : const <RoomPlayer>[];

    // Ordre du podium à l'écran : 2e, 1er, 3e.
    final steps = [
      if (ranking.length > 1) (ranking[1], 2, 110.0, AppColors.cyan),
      (ranking[0], 1, 150.0, AppColors.yellow),
      if (ranking.length > 2) (ranking[2], 3, 80.0, AppColors.orange),
    ];

    return ConfettiOverlay(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GameIcon(
                  GameIconKind.trophy,
                  size: 40,
                  color: AppColors.yellow,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.podiumTitle,
                  style: fredoka(
                    size: 30,
                    weight: FontWeight.w700,
                    color: AppColors.white,
                    shadows: textShadow,
                  ),
                ),
              ],
            ),
            if (widget.stake > 0) ...[
              const SizedBox(height: 10),
              Center(
                child: BounceIn(
                  delay: const Duration(milliseconds: 1200),
                  child: switch (widget.winnings[widget.myId]) {
                    final int won => BetBanner(text: l10n.betWon(won)),
                    null => BetBanner(
                      text: l10n.betLost(widget.stake),
                      highlight: false,
                    ),
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (player, place, height, color) in steps)
                  Expanded(
                    child: BounceIn(
                      delay: Duration(milliseconds: 250 + (3 - place) * 250),
                      slideY: 0.5,
                      from: 0.2,
                      child: _PodiumStep(
                        player: player,
                        place: place,
                        height: height,
                        color: color,
                        isMe: player.clientId == widget.myId,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: rest.isEmpty
                  ? const SizedBox()
                  : Align(
                      alignment: Alignment.topCenter,
                      child: GameCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final (i, p) in rest.indexed)
                              ListTile(
                                leading: Text(
                                  '${i + 4}',
                                  style: fredoka(
                                    size: 18,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                title: Text(
                                  p.nickname,
                                  style: fredoka(
                                    size: 17,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Text(
                                  l10n.pointsShort(p.score),
                                  style: fredoka(
                                    size: 17,
                                    weight: FontWeight.w700,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            CandyButton(
              label: l10n.playAgain,
              icon: Icons.replay_rounded,
              onPressed: widget.onPlayAgain,
            ),
            const SizedBox(height: 10),
            CandyButton(
              label: l10n.leaveRoom,
              icon: Icons.logout_rounded,
              color: AppColors.white,
              height: 54,
              fontSize: 19,
              onPressed: widget.onLeave,
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.player,
    required this.place,
    required this.height,
    required this.color,
    required this.isMe,
  });

  final RoomPlayer player;
  final int place;
  final double height;
  final Color color;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          PlayerAvatar(
            nickname: player.nickname,
            seed: player.clientId,
            size: place == 1 ? 64 : 52,
            bot: player.bot,
          ),
          const SizedBox(height: 6),
          Text(
            isMe ? l10n.youBadge : player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: fredoka(
              size: 15,
              weight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          Text(
            l10n.pointsShort(player.score),
            style: fredoka(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.depthOf(color),
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GameIcon(GameIconKind.medal(place), size: 42),
          ),
        ],
      ),
    );
  }
}
