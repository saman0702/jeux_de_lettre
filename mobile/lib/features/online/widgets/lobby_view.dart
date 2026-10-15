import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../../game/widgets/labels.dart';
import '../data/room_models.dart';
import 'player_avatar.dart';

/// Waiting room: code to share, players, ready button (or quick match timer).
class LobbyView extends StatelessWidget {
  const LobbyView({
    super.key,
    required this.room,
    required this.myId,
    required this.onReady,
  });

  final RoomState room;
  final String myId;
  final ValueChanged<bool> onReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = room.player(myId);
    final settings = room.settings;

    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: fredoka(
          size: 14,
          weight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!room.quick) _CodeCard(code: room.code),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              chip(l10n.roundsCount(settings.rounds)),
              chip(l10n.secondsShort(settings.roundDuration)),
              chip(settings.difficulty.label(l10n)),
              for (final c in settings.categories) chip(c.emoji),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: GameCard(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                  children: [
                    for (final p in room.players)
                      BounceIn(
                        key: ValueKey(p.clientId),
                        from: 0,
                        child: _PlayerSeat(
                          player: p,
                          isHost: p.clientId == room.hostId,
                          isMe: p.clientId == myId,
                          showReady: !room.quick,
                        ),
                      ),
                    for (
                      var i = room.players.length;
                      i < settings.maxPlayers;
                      i++
                    )
                      const _EmptySeat(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (room.quick)
            _QuickStatus(room: room)
          else ...[
            Text(
              room.players.length < 2 ? l10n.waitingForPlayers : l10n.readyHint,
              textAlign: TextAlign.center,
              style: fredoka(
                size: 15,
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            CandyButton(
              key: const Key('ready_button'),
              label: (me?.ready ?? false)
                  ? l10n.notReadyButton
                  : l10n.readyButton,
              icon: (me?.ready ?? false)
                  ? Icons.close_rounded
                  : Icons.check_rounded,
              color: (me?.ready ?? false) ? AppColors.white : AppColors.green,
              textColor: (me?.ready ?? false) ? AppColors.ink : AppColors.white,
              onPressed: () => onReady(!(me?.ready ?? false)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GameCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Text(
            l10n.roomCode,
            style: fredoka(size: 14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final char in code.split(''))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: LetterTile(letter: char, size: 42),
                ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: l10n.copyCode,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  const _PlayerSeat({
    required this.player,
    required this.isHost,
    required this.isMe,
    required this.showReady,
  });

  final RoomPlayer player;
  final bool isHost;
  final bool isMe;
  final bool showReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatar(
              nickname: player.nickname,
              seed: player.clientId,
              connected: player.connected,
            ),
            if (isHost)
              const Positioned(
                top: -12,
                left: 14,
                child: Text('👑', style: TextStyle(fontSize: 18)),
              ),
            if (showReady && player.ready)
              const Positioned(
                bottom: -2,
                right: -4,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.green,
                  child: Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AppColors.white,
                  ),
                ),
              ),
            if (!player.connected)
              const Positioned(
                bottom: -4,
                right: -6,
                child: Text('📡', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isMe ? l10n.youBadge : player.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: fredoka(
            size: 13,
            weight: isMe ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cloud,
            border: Border.all(color: const Color(0xFFDCD3F2), width: 2),
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }
}

class _QuickStatus extends StatelessWidget {
  const _QuickStatus({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final startsIn = (room.until(room.startsAt).inMilliseconds / 1000).ceil();
    final text = room.startsAt == null
        ? l10n.waitingForPlayers
        : l10n.quickStartsIn(startsIn);
    return GameCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '⚡ $text',
        key: const Key('quick_status'),
        textAlign: TextAlign.center,
        style: fredoka(
          size: 20,
          weight: FontWeight.w700,
          color: AppColors.purple,
        ),
      ),
    );
  }
}
