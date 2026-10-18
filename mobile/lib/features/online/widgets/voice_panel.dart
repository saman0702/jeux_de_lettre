import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_dialog.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../data/room_models.dart';
import '../online_controller.dart';
import '../voice/voice_session.dart';
import 'player_avatar.dart';

/// Ouvre le salon vocal (sheet aligné sur réglages / chat).
Future<void> showVoiceSheet(
  BuildContext context, {
  required OnlineController online,
  required RoomState room,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.6),
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.72),
              child: Material(
                color: AppColors.cloud,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.cyan, width: 5),
                    ),
                  ),
                  child: VoicePanel(
                    online: online,
                    room: online.room ?? room,
                    manageSession: false,
                    asSheet: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Salon vocal ; l'hôte peut muter / exclure.
///
/// Si [manageSession] est faux, [VoiceBridge] gère la connexion Agora.
class VoicePanel extends StatefulWidget {
  const VoicePanel({
    super.key,
    required this.online,
    required this.room,
    this.manageSession = true,
    this.asSheet = false,
  });

  final OnlineController online;
  final RoomState room;

  /// false quand un [VoiceBridge] parent tient déjà la session.
  final bool manageSession;

  /// Affichage dans un bottom sheet (poignée + fermer).
  final bool asSheet;

  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  final VoiceSession _session = VoiceSession.instance;
  final _subs = <StreamSubscription<dynamic>>[];
  bool _joining = false;

  bool get _isHost => _room.hostId == widget.online.clientId;

  RoomState get _room => widget.online.room ?? widget.room;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    widget.online.addListener(_onSession);
    if (widget.manageSession) {
      _subs.add(widget.online.voiceCredentials.listen(_onCredentials));
      _subs.add(widget.online.voiceForceMute.listen(_session.applyForceMute));
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryJoin());
    }
  }

  @override
  void didUpdateWidget(covariant VoicePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.manageSession) return;
    if (_room.voice.open &&
        !oldWidget.room.voice.open &&
        !_session.joined) {
      _tryJoin();
    }
    if (!_room.voice.open && _session.joined) {
      _session.leave();
    }
  }

  void _onSession() {
    if (!mounted) return;
    final forced = _room.voice.isMuted(widget.online.clientId);
    if (forced != _session.forceMuted) {
      unawaited(_session.applyForceMute(forced));
    }
    setState(() {});
  }

  void _requestJoin() {
    final voice = _room.voice;
    if (!voice.open || !voice.enabled) return;
    if (voice.isExcluded(widget.online.clientId)) {
      _session.markExcluded();
      return;
    }
    if (_joining || _session.joined) return;
    setState(() => _joining = true);
    widget.online.requestVoiceJoin();
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (mounted && _joining && !_session.joined) {
        setState(() => _joining = false);
      }
    });
  }

  Future<void> _tryJoin() async => _requestJoin();

  Future<void> _onCredentials(VoiceCredentials creds) async {
    await _session.join(
      appId: creds.appId,
      channel: creds.channel,
      token: creds.token,
      uid: creds.uid,
      startMuted: creds.muted,
    );
    if (mounted) setState(() => _joining = false);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    widget.online.removeListener(_onSession);
    _session.removeListener(_onSession);
    super.dispose();
  }

  void _close() {
    if (widget.asSheet && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = _room;
    final voice = room.voice;

    if (!voice.enabled) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.asSheet) _SheetHeader(onClose: _close),
            Text(
              l10n.voiceUnavailable,
              textAlign: TextAlign.center,
              style: fredoka(size: 14, color: AppColors.inkSoft),
            ),
            if (widget.asSheet) ...[
              const SizedBox(height: 16),
              CandyButton(
                label: l10n.cancel,
                color: AppColors.white,
                onPressed: _close,
              ),
            ],
          ],
        ),
      );
    }

    final humans = [
      for (final p in room.players)
        if (!p.bot) p,
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.asSheet) ...[
          _SheetHeader(onClose: _close),
          const SizedBox(height: 4),
        ] else ...[
          Row(
            children: [
              const GameIcon(
                GameIconKind.group,
                size: 22,
                color: AppColors.cyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.voiceChatTitle,
                  style: fredoka(
                    size: 17,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              InfoTip(
                title: l10n.voiceChatTitle,
                message: l10n.voiceChatHelp,
                okLabel: l10n.gotIt,
                icon: GameIconKind.group,
                accent: AppColors.cyan,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_session.excluded)
          Text(
            l10n.voiceKickedNotice,
            textAlign: TextAlign.center,
            style: fredoka(size: 14, color: AppColors.pink),
          )
        else ...[
          CandyButton(
            label: _session.micOn ? l10n.voiceMuteSelf : l10n.voiceUnmuteSelf,
            icon: _session.micOn
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            color: _session.forceMuted
                ? AppColors.inkSoft
                : (_session.micOn ? AppColors.green : AppColors.white),
            onPressed: _session.forceMuted
                ? null
                : () {
                    if (!_session.joined) {
                      _requestJoin();
                      return;
                    }
                    unawaited(_session.setMicOn(!_session.micOn));
                  },
          ),
          if (!_session.joined) ...[
            const SizedBox(height: 8),
            CandyButton(
              label: _joining ? l10n.voiceConnecting : l10n.voiceJoin,
              icon: Icons.headset_mic_rounded,
              color: AppColors.cyan,
              textColor: AppColors.white,
              loading: _joining,
              onPressed: _joining ? null : _requestJoin,
            ),
          ],
          if (_isHost && _session.joined) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final allMuted = _allOthersMuted(
                  humans,
                  voice,
                  hostId: room.hostId,
                );
                return CandyButton(
                  label: allMuted ? l10n.voiceUnmuteAll : l10n.voiceMuteAll,
                  icon: allMuted
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: allMuted ? AppColors.green : AppColors.orange,
                  textColor: AppColors.white,
                  onPressed: () {
                    widget.online.voiceMuteAll(!allMuted);
                    if (!allMuted) unawaited(_session.setMicOn(false));
                  },
                );
              },
            ),
          ],
          if (_session.forceMuted) ...[
            const SizedBox(height: 6),
            Text(
              l10n.voiceHostMutedYou,
              textAlign: TextAlign.center,
              style: fredoka(size: 13, color: AppColors.orange),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.voiceChatTitle,
            style: fredoka(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in humans)
            _VoiceRow(
              player: p,
              isMe: p.clientId == widget.online.clientId,
              forceMuted: voice.isMuted(p.clientId),
              selfMuted: p.clientId == widget.online.clientId &&
                  (!_session.micOn || _session.forceMuted),
              excluded: voice.isExcluded(p.clientId),
              isHost: p.clientId == room.hostId,
              canModerate: _isHost &&
                  p.clientId != widget.online.clientId &&
                  !voice.isExcluded(p.clientId),
              onMute: () => widget.online.voiceMute(
                p.clientId,
                !voice.isMuted(p.clientId),
              ),
              onExclude: () => widget.online.voiceExclude(p.clientId),
            ),
        ],
        if (widget.asSheet) ...[
          const SizedBox(height: 12),
          CandyButton(
            label: l10n.cancel,
            color: AppColors.white,
            onPressed: _close,
          ),
        ],
      ],
    );

    if (!widget.asSheet) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: body,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SingleChildScrollView(child: body),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const GameIcon(
              GameIconKind.group,
              size: 26,
              color: AppColors.cyan,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.voiceChatTitle,
                style: fredoka(
                  size: 20,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            InfoTip(
              title: l10n.voiceChatTitle,
              message: l10n.voiceChatHelp,
              okLabel: l10n.gotIt,
              icon: GameIconKind.group,
              accent: AppColors.cyan,
              size: 22,
            ),
            const SizedBox(width: 6),
            RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.cancel,
              color: AppColors.white,
              iconColor: AppColors.purple,
              size: 42,
              onPressed: onClose,
            ),
          ],
        ),
      ],
    );
  }
}

bool _allOthersMuted(
  List<RoomPlayer> humans,
  RoomVoice voice, {
  required String hostId,
}) {
  final peers = [
    for (final p in humans)
      if (p.clientId != hostId && !voice.isExcluded(p.clientId)) p,
  ];
  if (peers.isEmpty) return false;
  return peers.every((p) => voice.isMuted(p.clientId));
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.player,
    required this.isMe,
    required this.forceMuted,
    required this.selfMuted,
    required this.excluded,
    required this.isHost,
    required this.canModerate,
    required this.onMute,
    required this.onExclude,
  });

  final RoomPlayer player;
  final bool isMe;
  final bool forceMuted;
  final bool selfMuted;
  final bool excluded;
  final bool isHost;
  final bool canModerate;
  final VoidCallback onMute;
  final VoidCallback onExclude;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = forceMuted || selfMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            PlayerAvatar.of(player, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? l10n.youBadge : player.nickname,
                    style: fredoka(size: 15, weight: FontWeight.w700),
                  ),
                  if (excluded)
                    Text(
                      l10n.voiceExcludedBadge,
                      style: fredoka(size: 12, color: AppColors.pink),
                    )
                  else if (muted)
                    Text(
                      l10n.voiceMutedBadge,
                      style: fredoka(size: 12, color: AppColors.orange),
                    )
                  else if (isHost && isMe)
                    Text(
                      l10n.voiceHostBadge,
                      style: fredoka(size: 12, color: AppColors.cyan),
                    ),
                ],
              ),
            ),
            if (canModerate) ...[
              Material(
                color: forceMuted ? AppColors.orange : AppColors.green,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: onMute,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          forceMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          forceMuted
                              ? l10n.voiceUnmutePlayer
                              : l10n.voiceMutePlayer,
                          style: fredoka(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.voiceExcludePlayer,
                onPressed: onExclude,
                icon: const Icon(
                  Icons.person_remove_rounded,
                  color: AppColors.pink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
