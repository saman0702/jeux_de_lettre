import 'package:flutter/material.dart';
import '../../home/country_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../../game/data/models.dart';
import '../../game/widgets/labels.dart';
import '../data/room_models.dart';
import '../../wallet/bet_banner.dart';
import '../../wallet/level_badge.dart';
import 'player_avatar.dart';
import '../../shop/look_styles.dart';
import '../../../core/widgets/game_icon.dart';

/// Salle d'attente : code à partager, joueurs, bouton « prêt » (ou minuteur de
/// partie rapide).
class LobbyView extends StatelessWidget {
  const LobbyView({
    super.key,
    required this.room,
    required this.myId,
    required this.onReady,
    this.onAddBot,
    this.onRemoveBot,
    this.onReport,
    this.onOpenChat,
    this.onOpenHistory,
    this.onDeleteRoom,
  });

  /// Salon gardé : discussion (groupe et privé) et historique des parties.
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenHistory;

  /// Créateur d'un salon gardé : le supprimer.
  final VoidCallback? onDeleteRoom;

  final RoomState room;
  final String myId;
  final ValueChanged<bool> onReady;

  /// Hôte uniquement : ajouter ou retirer des adversaires ordinateur.
  final ValueChanged<Difficulty>? onAddBot;
  final ValueChanged<String>? onRemoveBot;

  /// Signaler la photo d'un autre joueur.
  final ValueChanged<RoomPlayer>? onReport;

  Future<void> _pickBotLevel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final level = await showModalBottomSheet<Difficulty>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GameIconBadge(
                    GameIconKind.bot,
                    color: AppColors.purpleLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.botLevel,
                    style: fredoka(size: 22, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final (level, color) in [
                (Difficulty.easy, AppColors.green),
                (Difficulty.normal, AppColors.yellow),
                (Difficulty.hard, AppColors.pink),
              ]) ...[
                CandyButton(
                  label: level.label(l10n),
                  color: color,
                  onPressed: () => Navigator.pop(context, level),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
    if (level != null) onAddBot?.call(level);
  }

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
          // Code uniquement pour le privé ; le public se rejoint depuis la liste.
          if (!room.quick && !settings.public) _CodeCard(code: room.code),
          if (!room.quick && settings.public) _PublicRoomBanner(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              chip(
                settings.public
                    ? l10n.visibilityPublic
                    : l10n.visibilityPrivate,
              ),
              chip(l10n.roundsCount(settings.rounds)),
              chip(durationLabel(l10n, settings.roundDuration)),
              chip(settings.difficulty.label(l10n)),
              if (settings.iq) chip(l10n.iqBadge),
              // Partie mélangée : chacun répond dans sa langue.
              if ({
                    for (final p in room.players)
                      if (!p.bot) p.language,
                  }.length >
                  1)
                chip(l10n.mixedLanguages),
              if (settings.strictSpelling) chip(l10n.strictSpellingChip),
              if (settings.elimination) chip(l10n.formatElimination),
              if (settings.relay) chip(l10n.formatRelay),
              if (settings.theme != RoomTheme.none)
                chip(switch (settings.theme) {
                  RoomTheme.geography => l10n.themeGeography,
                  RoomTheme.names => l10n.themeNames,
                  RoomTheme.nature => l10n.themeNature,
                  RoomTheme.none => '',
                }),
              // Le QI n'a pas de catégories.
              if (!settings.iq)
              for (final c in settings.categories)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GameIcon(c.icon, size: 20),
                ),
            ],
          ),
          if (room.saved && (onOpenChat != null || onOpenHistory != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onOpenChat != null)
                  Expanded(
                    child: CandyButton(
                      key: const Key('lobby_chat'),
                      label: l10n.roomChatButton,
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.cyan,
                      height: 46,
                      fontSize: 16,
                      onPressed: onOpenChat,
                    ),
                  ),
                if (onOpenChat != null && onOpenHistory != null)
                  const SizedBox(width: 10),
                if (onOpenHistory != null)
                  Expanded(
                    child: CandyButton(
                      key: const Key('lobby_history'),
                      label: l10n.roomHistoryButton,
                      icon: Icons.history_rounded,
                      color: AppColors.white,
                      height: 46,
                      fontSize: 16,
                      onPressed: onOpenHistory,
                    ),
                  ),
              ],
            ),
          ],
          if (room.saved && room.creatorId == myId && onDeleteRoom != null)
            Center(
              child: TextButton.icon(
                key: const Key('lobby_delete_room'),
                onPressed: onDeleteRoom,
                icon: const Icon(Icons.delete_rounded, color: AppColors.white),
                label: Text(
                  l10n.deleteRoomTitle,
                  style: fredoka(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          if (settings.betting) ...[
            const SizedBox(height: 10),
            Center(
              child: BetBanner(
                text:
                    '${l10n.stakeShort(settings.stake)} · ${l10n.potLabel(settings.stake * room.players.length)}',
              ),
            ),
          ],
          if (settings.prize) ...[
            const SizedBox(height: 10),
            Center(
              child: BetBanner(
                text: l10n.prizePotLabel(settings.stake),
              ),
            ),
          ],
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
                          onRemove: p.bot && onRemoveBot != null
                              ? () => onRemoveBot!(p.clientId)
                              : null,
                          onReport:
                              p.avatarUrl != null &&
                                  p.clientId != myId &&
                                  onReport != null
                              ? () => onReport!(p)
                              : null,
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
            if (onAddBot != null &&
                room.players.length < settings.maxPlayers) ...[
              CandyButton(
                key: const Key('add_bot_button'),
                label: l10n.addBot,
                gameIcon: GameIconKind.bot,
                color: AppColors.white,
                onPressed: () => _pickBotLevel(context),
              ),
              const SizedBox(height: 10),
            ],
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

class _PublicRoomBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GameCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          const GameIconBadge(
            GameIconKind.public,
            color: AppColors.green,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.publicRoomLobbyHelp,
              style: fredoka(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: l10n.copyCode,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
                },
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton.filledTonal(
                key: const Key('share_code'),
                tooltip: l10n.shareInvite,
                onPressed: () {
                  SharePlus.instance.share(
                    ShareParams(text: l10n.inviteMessage(code)),
                  );
                },
                icon: const Icon(Icons.share_rounded),
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
    this.onRemove,
    this.onReport,
  });

  final RoomPlayer player;
  final bool isHost;
  final bool isMe;
  final bool showReady;

  /// Affiché sur les bots, pour l'hôte.
  final VoidCallback? onRemove;

  /// Affiché sur les joueurs qui ont une photo.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerAvatar.of(player),
            if (isHost)
              const Positioned(
                top: -12,
                left: 14,
                child: GameIcon(GameIconKind.crown, size: 22),
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
                child: GameIcon(
                  GameIconKind.offline,
                  size: 18,
                  color: AppColors.red,
                ),
              ),
            if (!player.bot)
              Positioned(
                top: -6,
                right: -8,
                child: LevelBadge(level: player.level, size: 19),
              ),
            if (onReport != null)
              // Dans les limites de l'avatar pour rester touchable.
              Positioned(
                bottom: 0,
                left: 0,
                child: GestureDetector(
                  key: Key('report_${player.clientId}'),
                  onTap: onReport,
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.white,
                    child: GameIcon(
                      GameIconKind.flag,
                      size: 15,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ),
            if (onRemove != null)
              Positioned(
                top: -6,
                right: -8,
                child: GestureDetector(
                  key: Key('remove_${player.clientId}'),
                  onTap: onRemove,
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.red,
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drapeau du pays d'origine.
            CountryBadge(country: player.country, width: 16),
            if (player.country != null) const SizedBox(width: 3),
            Flexible(
              child: StyledNickname(
                isMe ? l10n.youBadge : player.nickname,
                styleId: player.nameStyle,
                size: 13,
                weight: isMe ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GameIcon(GameIconKind.bolt, size: 26, color: AppColors.orange),
          const SizedBox(width: 6),
          Text(
            text,
            key: const Key('quick_status'),
            style: fredoka(
              size: 20,
              weight: FontWeight.w700,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}
