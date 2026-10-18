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
import '../../shop/cosmetics.dart';
import '../../shop/look_styles.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/game_dialog.dart';
import '../online_controller.dart';
import 'salon_social.dart';
import 'voice_bridge.dart';

/// Fin de partie : podium avec médailles, confettis, puis rejouer ou quitter.
class PodiumView extends StatefulWidget {
  const PodiumView({
    super.key,
    required this.ranking,
    required this.myId,
    required this.onPlayAgain,
    this.stake = 0,
    this.prize = false,
    this.hostId = '',
    this.winnings = const {},
    this.room,
    this.online,
    this.onBonus,
  });

  final List<RoomPlayer> ranking;

  /// Paris : mise de chacun. Dotation : montant placé par l'hôte.
  final int stake;
  final bool prize;
  final String hostId;
  final Map<String, int> winnings;
  final String myId;
  final VoidCallback onPlayAgain;
  final RoomState? room;
  final OnlineController? online;
  final VoidCallback? onBonus;

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

    final victory = GameFeedbackScope.of(context).settings.victoryStyle;
    final online = widget.online;
    final room = widget.room;
    final showChat = online != null && room != null;
    final showVoice = showChat &&
        room.voice.enabled &&
        room.voice.open;
    // Place les FAB au-dessus des boutons bas (revanche ± bonus).
    final fabBottom = 14.0 + 56 + (widget.onBonus != null ? 56 : 0);

    return ConfettiOverlay(
      colors: victoryColors(victory),
      shape: victoryShapeFor(victory),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: GameIcon(
                    GameIconKind.trophy,
                    size: 36,
                    color: AppColors.yellow,
                  ),
                ),
                if (widget.stake > 0) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: BounceIn(
                      delay: const Duration(milliseconds: 1200),
                      child: switch (widget.winnings[widget.myId]) {
                        final int won => BetBanner(text: l10n.betWon(won)),
                        null => widget.prize
                            ? (widget.myId == widget.hostId
                                ? BetBanner(
                                    text: l10n.prizeLost(widget.stake),
                                    highlight: false,
                                  )
                                : const SizedBox.shrink())
                            : BetBanner(
                                text: l10n.betLost(widget.stake),
                                highlight: false,
                              ),
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (player, place, height, color) in steps)
                              Expanded(
                                child: BounceIn(
                                  delay: Duration(
                                    milliseconds: 250 + (3 - place) * 250,
                                  ),
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
                        if (rest.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          GameCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (i, p) in rest.indexed)
                                  ListTile(
                                    dense: true,
                                    leading: Text(
                                      '${i + 4}',
                                      style: fredoka(
                                        size: 18,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                    title: StyledNickname(
                                      p.nickname,
                                      styleId: p.nameStyle,
                                      size: 17,
                                      weight: FontWeight.w600,
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
                        ],
                        if (widget.room case final room?) ...[
                          const SizedBox(height: 10),
                          for (final p in widget.ranking)
                            if (p.title.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${p.nickname} · ${roomTitleLabel(l10n, p.title)}',
                                  textAlign: TextAlign.center,
                                  style: fredoka(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: AppColors.yellow,
                                  ),
                                ),
                              ),
                          WordReviewPanel(items: room.wordReview),
                          const SizedBox(height: 8),
                          if (online != null) ...[
                            ReactionBar(online: online),
                            // Espace pour la rangée FAB chat / vocal.
                            if (showChat || showVoice)
                              const SizedBox(height: 72),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CandyButton(
                        label: l10n.rematchVote(
                          widget.room?.rematchVotes ?? 0,
                          widget.room?.rematchNeed ?? 1,
                        ),
                        icon: Icons.replay_rounded,
                        onPressed: widget.onPlayAgain,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InfoTip(
                      title: l10n.playAgain,
                      message: l10n.rematchHelp,
                      okLabel: l10n.gotIt,
                      icon: GameIconKind.trophy,
                      accent: AppColors.green,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ],
                ),
                if (widget.onBonus != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CandyButton(
                          label: l10n.bonusRound,
                          icon: Icons.bolt_rounded,
                          color: AppColors.orange,
                          textColor: AppColors.white,
                          onPressed: widget.onBonus,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InfoTip(
                        title: l10n.bonusRound,
                        message: l10n.bonusRoundHelp,
                        okLabel: l10n.gotIt,
                        icon: GameIconKind.flame,
                        accent: AppColors.orange,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (showChat)
            Positioned(
              right: 16,
              bottom: fabBottom,
              // Pas de CircleBorder ici : ça masquait les hits sur la rangée
              // audio + chat (seule une zone ronde restait cliquable).
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showVoice) ...[
                    VoiceFab(
                      online: online,
                      room: room,
                      compact: true,
                      alignWithChat: true,
                    ),
                    const SizedBox(width: 8),
                  ],
                  RoundIconButton(
                    icon: Icons.chat_bubble_rounded,
                    tooltip: l10n.chatTitle,
                    color: AppColors.cyan,
                    iconColor: AppColors.white,
                    size: 56,
                    onPressed: () => showRoomChatSheet(context, online),
                  ),
                ],
              ),
            ),
        ],
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
          PlayerAvatar.of(player, size: place == 1 ? 64 : 52),
          const SizedBox(height: 6),
          StyledNickname(
            isMe ? l10n.youBadge : player.nickname,
            styleId: player.nameStyle,
            size: 15,
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
