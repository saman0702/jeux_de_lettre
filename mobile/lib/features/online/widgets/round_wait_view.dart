import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../../game/widgets/round_view.dart';
import '../data/room_models.dart';
import 'player_avatar.dart';

/// Shown after sending your answers (or when joining mid-round): who is
/// still writing, and the round timer.
class RoundWaitView extends StatelessWidget {
  const RoundWaitView({
    super.key,
    required this.room,
    required this.spectating,
  });

  final RoomState room;
  final bool spectating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = room.round!;
    final playing = room.players.where((p) => p.playing).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LetterTile(letter: round.letter, size: 56),
              const Spacer(),
              TimerBadge(
                remaining: round.remaining(),
                total: Duration(seconds: round.duration),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BounceIn(
            from: 0.3,
            child: Text(
              spectating ? '👀\n${l10n.spectating}' : '✅\n${l10n.answersSent}',
              textAlign: TextAlign.center,
              style: fredoka(
                size: 24,
                weight: FontWeight.w700,
                color: AppColors.white,
                shadows: textShadow,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.waitingOthers,
            textAlign: TextAlign.center,
            style: fredoka(
              size: 16,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GameCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                children: [
                  for (final p in playing)
                    ListTile(
                      leading: PlayerAvatar(
                        nickname: p.nickname,
                        seed: p.clientId,
                        size: 40,
                        connected: p.connected,
                        bot: p.bot,
                      ),
                      title: Text(
                        p.nickname,
                        style: fredoka(size: 17, weight: FontWeight.w600),
                      ),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: p.finished
                            ? const Icon(
                                Icons.check_circle_rounded,
                                key: ValueKey('done'),
                                color: AppColors.green,
                                size: 30,
                              )
                            : const Text(
                                '✍️',
                                key: ValueKey('writing'),
                                style: TextStyle(fontSize: 24),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
