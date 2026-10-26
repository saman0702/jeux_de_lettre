import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../l10n/app_localizations.dart';
import '../data/room_models.dart';
import '../online_controller.dart';
import '../voice/voice_session.dart';
import 'player_avatar.dart';
import 'voice_panel.dart';

/// Garde la session Agora active pendant toute la salle (manche + podium).
class VoiceBridge extends StatefulWidget {
  const VoiceBridge({
    super.key,
    required this.online,
    required this.room,
  });

  final OnlineController online;
  final RoomState room;

  @override
  State<VoiceBridge> createState() => _VoiceBridgeState();
}

class _VoiceBridgeState extends State<VoiceBridge> {
  final _session = VoiceSession.instance;
  final _subs = <StreamSubscription<dynamic>>[];
  bool _joining = false;
  /// Évite de redemander un token en boucle si le join échoue.
  bool _joinRequested = false;

  @override
  void initState() {
    super.initState();
    _subs.add(widget.online.voiceCredentials.listen(_onCredentials));
    _subs.add(widget.online.voiceForceMute.listen(_session.applyForceMute));
    _subs.add(widget.online.errors.listen(_onError));
    _subs.add(widget.online.voiceKicked.listen((_) {
      _session.markExcluded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).voiceKickedNotice),
          ),
        );
      }
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant VoiceBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasOpen = oldWidget.room.voice.open;
    final isOpen = widget.room.voice.open;
    if (!wasOpen && isOpen) {
      _joinRequested = false;
    }
    if (wasOpen && !isOpen) {
      _joinRequested = false;
      _joining = false;
    }
    _sync();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _onError(String code) {
    if (code == 'voice_closed' ||
        code == 'voice_unavailable' ||
        code == 'voice_excluded') {
      _joining = false;
      // voice_closed : on réessaiera quand open repasse à true.
      if (code == 'voice_closed') {
        _joinRequested = false;
      }
    }
  }

  void _sync() {
    final voice = widget.room.voice;
    if (!voice.enabled || !voice.open) {
      if (_session.joined) unawaited(_session.leave());
      return;
    }
    if (voice.isExcluded(widget.online.clientId)) {
      _session.markExcluded();
      return;
    }
    // Resync mute hôte (si l'event WS a été raté).
    final forced = voice.isMuted(widget.online.clientId);
    if (forced != _session.forceMuted) {
      unawaited(_session.applyForceMute(forced));
    }
    if (!_session.joined &&
        !_joining &&
        !_joinRequested &&
        !_session.excluded) {
      _joining = true;
      _joinRequested = true;
      widget.online.requestVoiceJoin();
      Future<void>.delayed(const Duration(seconds: 8), () {
        if (mounted) _joining = false;
      });
    }
  }

  Future<void> _onCredentials(VoiceCredentials creds) async {
    await _session.join(
      appId: creds.appId,
      channel: creds.channel,
      token: creds.token,
      uid: creds.uid,
      startMuted: creds.muted,
    );
    _joining = false;
    _joinRequested = true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Boutons micro : soi + (hôte) mute individuel / tous + panneau.
///
/// [compact] : manche en cours — seulement micro (+ panneau hôte), sans
/// pastilles joueurs qui recouvrent le clavier.
class VoiceFab extends StatelessWidget {
  const VoiceFab({
    super.key,
    required this.online,
    required this.room,
    this.compact = false,
    this.alignWithChat = false,
    this.inHeader = false,
  });

  final OnlineController online;
  final RoomState room;

  /// Mode réduit pendant la saisie (au-dessus du clavier).
  final bool compact;

  /// Même taille que le FAB chat (56) pour l'alignement podium.
  final bool alignWithChat;

  /// Dans la barre du haut (à droite du titre) : petits boutons, place
  /// réservée, rien n'est recouvert ; la liste des joueurs à couper est dans
  /// le panneau.
  final bool inHeader;

  Future<void> _openSheet(BuildContext context) {
    return showVoiceSheet(
      context,
      online: online,
      room: online.room ?? room,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!room.voice.enabled || !room.voice.open) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final session = VoiceSession.instance;
    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final liveRoom = online.room ?? room;
        final isHost = liveRoom.hostId == online.clientId;
        return ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final on = session.micOn;
            final peers = [
              for (final p in liveRoom.players)
                if (!p.bot &&
                    p.clientId != online.clientId &&
                    !liveRoom.voice.isExcluded(p.clientId))
                  p,
            ];
            final allMuted = peers.isNotEmpty &&
                peers.every((p) => liveRoom.voice.isMuted(p.clientId));
            final micSize = alignWithChat
                ? 56.0
                : (inHeader ? 38.0 : (compact ? 44.0 : 52.0));
            final hostSize = alignWithChat
                ? 48.0
                : (inHeader ? 34.0 : (compact ? 40.0 : 44.0));
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isHost &&
                    session.joined &&
                    peers.isNotEmpty &&
                    !compact &&
                    !inHeader) ...[
                  Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.voiceMutePlayer,
                          style: fredoka(
                            size: 11,
                            weight: FontWeight.w700,
                            color: AppColors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in peers)
                              _PeerMuteChip(
                                player: p,
                                muted: liveRoom.voice.isMuted(p.clientId),
                                onToggle: () => online.voiceMute(
                                  p.clientId,
                                  !liveRoom.voice.isMuted(p.clientId),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHost && session.joined) ...[
                      // Mute all : visible hors manche compacte clavier, ou
                      // sur le podium (alignWithChat).
                      if (!compact || alignWithChat || inHeader) ...[
                        Tooltip(
                          message: allMuted
                              ? l10n.voiceUnmuteAll
                              : l10n.voiceMuteAll,
                          child: RoundIconButton(
                            icon: allMuted
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color:
                                allMuted ? AppColors.green : AppColors.orange,
                            iconColor: AppColors.white,
                            size: hostSize,
                            onPressed: () {
                              online.voiceMuteAll(!allMuted);
                              if (!allMuted) session.setMicOn(false);
                            },
                          ),
                        ),
                        SizedBox(width: inHeader ? 6 : 8),
                      ],
                      Tooltip(
                        message: l10n.voiceChatTitle,
                        child: RoundIconButton(
                          icon: Icons.groups_rounded,
                          color: AppColors.purpleLight,
                          iconColor: AppColors.white,
                          size: hostSize,
                          onPressed: () => _openSheet(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Tooltip(
                      message: session.forceMuted
                          ? l10n.voiceHostMutedYou
                          : (on ? l10n.voiceMuteSelf : l10n.voiceUnmuteSelf),
                      child: GestureDetector(
                        onLongPress: () => _openSheet(context),
                        child: RoundIconButton(
                          icon: on ? Icons.mic_rounded : Icons.mic_off_rounded,
                          color: session.forceMuted
                              ? AppColors.inkSoft
                              : (on ? AppColors.green : AppColors.cyan),
                          iconColor: AppColors.white,
                          size: micSize,
                          onPressed: () async {
                            if (!session.joined) {
                              await _openSheet(context);
                              return;
                            }
                            if (session.forceMuted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.voiceHostMutedYou),
                                ),
                              );
                              await _openSheet(context);
                              return;
                            }
                            await session.setMicOn(!on);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Pastille hôte : tap = couper / rendre le micro de ce joueur.
class _PeerMuteChip extends StatelessWidget {
  const _PeerMuteChip({
    required this.player,
    required this.muted,
    required this.onToggle,
  });

  final RoomPlayer player;
  final bool muted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: muted
                ? AppColors.orange.withValues(alpha: 0.95)
                : AppColors.green.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.white, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerAvatar.of(player, size: 28),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  player.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: fredoka(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 18,
                color: AppColors.white,
              ),
              Semantics(
                label: muted ? l10n.voiceUnmutePlayer : l10n.voiceMutePlayer,
                button: true,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
