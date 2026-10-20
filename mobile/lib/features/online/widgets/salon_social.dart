import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../animations/victory/confetti.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../core/widgets/game_dialog.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../../game/data/models.dart';
import '../../game/widgets/country_flag.dart';
import '../../game/widgets/labels.dart';
import '../../shop/cosmetics.dart';
import '../data/room_models.dart';
import '../online_controller.dart';
import '../room_history.dart';

/// Barre de réactions (stickers) pendant results / lightning / finished.
class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.online});

  final OnlineController online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = online.room;
    if (room == null) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.reactionsTitle,
              style: fredoka(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 6),
            InfoTip(
              title: l10n.reactionsTitle,
              message: l10n.reactionsInfoHelp,
              okLabel: l10n.gotIt,
              icon: GameIconKind.smile,
              accent: AppColors.pink,
              color: AppColors.white,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (room.reactions.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final r in room.reactions.reversed.take(12))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${r.sticker.emoji} ${r.nickname}',
                      style: fredoka(size: 14, color: AppColors.white),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final s in RoomSticker.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => online.react(s),
                  child: Container(
                    width: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chat écrit (débloqué aux pièces) + historique.
/// Ouvre le chat du salon dans un bottom sheet.
Future<void> showRoomChatSheet(
  BuildContext context,
  OnlineController online,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.58,
            child: ListenableBuilder(
              listenable: online,
              builder: (_, _) => RoomChatPanel(online: online),
            ),
          ),
        ),
      );
    },
  );
}

/// Contenu du chat (utilisé dans le bottom sheet).
class RoomChatPanel extends StatefulWidget {
  const RoomChatPanel({super.key, required this.online});

  final OnlineController online;

  @override
  State<RoomChatPanel> createState() => _RoomChatPanelState();
}

class _RoomChatPanelState extends State<RoomChatPanel> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context);
    final price = widget.online.room?.chatUnlockPrice ?? 25;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatUnlockTitle),
        content: Text(l10n.chatUnlockHelp(price)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.online.unlockChat();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(l10n, e.code))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.online.sendChat(text);
    _text.clear();
  }

  /// Toucher un pseudo le tague dans le message en cours (« @pseudo »).
  void _tag(String nickname) {
    final tag = '@${nickname.replaceAll(' ', '')} ';
    final current = _text.text;
    _text.text = current.isEmpty || current.endsWith(' ')
        ? '$current$tag'
        : '$current $tag';
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
  }

  /// Messages privés : choisir un membre du salon.
  Future<void> _openPrivate(RoomState room, String me) async {
    final l10n = AppLocalizations.of(context);
    final others = [
      for (final p in room.players)
        if (!p.bot && p.clientId != me) p,
    ];
    final picked = await showModalBottomSheet<RoomPlayer>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.chatPrivatePick,
                style: fredoka(size: 18, weight: FontWeight.w700),
              ),
            ),
            for (final p in others)
              ListTile(
                key: Key('pick_private_${p.clientId}'),
                leading: const Icon(Icons.lock_rounded, color: AppColors.purple),
                title: Text(p.nickname, style: fredoka(size: 16)),
                onTap: () => Navigator.pop(ctx, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivateChatScreen(
          code: room.code,
          otherId: picked.clientId,
          otherName: picked.nickname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = widget.online.room;
    final me = widget.online.me;
    if (room == null || me == null) {
      return Center(
        child: Text(
          l10n.chatTitle,
          style: fredoka(size: 16, color: AppColors.inkSoft),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                l10n.chatTitle,
                style: fredoka(
                  size: 20,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              InfoTip(
                title: l10n.chatTitle,
                message: l10n.chatInfoHelp,
                okLabel: l10n.gotIt,
                icon: GameIconKind.smile,
                accent: AppColors.cyan,
                size: 20,
              ),
              const Spacer(),
              if (room.saved)
                TextButton.icon(
                  key: const Key('chat_private'),
                  onPressed: () => _openPrivate(room, me.clientId),
                  icon: const Icon(Icons.lock_person_rounded, size: 20),
                  label: Text(l10n.chatPrivateButton),
                ),
              if (!me.chatUnlocked && room.saved)
                Tooltip(
                  message: l10n.chatUnlockButton(room.chatUnlockPrice),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _busy ? null : _unlock,
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_rounded,
                              color: AppColors.cyan,
                              size: 28,
                            ),
                            Positioned(
                              right: 2,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            if (_busy)
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: room.chat.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatHint,
                        textAlign: TextAlign.center,
                        style: fredoka(size: 14, color: AppColors.inkSoft),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final m in room.chat)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: m.mentionsMe(me.clientId)
                                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
                                : EdgeInsets.zero,
                            decoration: m.mentionsMe(me.clientId)
                                ? BoxDecoration(
                                    color: AppColors.yellow.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _tag(m.nickname),
                                    text: '${m.nickname}: ',
                                    style: fredoka(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: AppColors.purple,
                                    ),
                                  ),
                                  TextSpan(
                                    text: m.text,
                                    style: fredoka(
                                      size: 14,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // Conversation de groupe gratuite : la saisie est toujours là.
          ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 120,
                    style: fredoka(size: 15, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: l10n.chatHint,
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.ink.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.ink.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  style: IconButton.styleFrom(backgroundColor: AppColors.green),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Défi éclair : QCM 10 s entre deux manches.
class LightningView extends StatefulWidget {
  const LightningView({super.key, required this.online});

  final OnlineController online;

  @override
  State<LightningView> createState() => _LightningViewState();
}

class _LightningViewState extends State<LightningView>
    with SingleTickerProviderStateMixin {
  /// Choix local immédiat (le room_state peut arriver un peu après).
  String? _localPick;

  /// Résultat serveur déjà annoncé (son / haptic / bannière).
  bool _resultPlayed = false;
  bool? _hit;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    widget.online.addListener(_onOnline);
  }

  @override
  void didUpdateWidget(covariant LightningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online) {
      oldWidget.online.removeListener(_onOnline);
      widget.online.addListener(_onOnline);
    }
  }

  @override
  void dispose() {
    widget.online.removeListener(_onOnline);
    _shake.dispose();
    super.dispose();
  }

  void _onOnline() {
    if (!mounted) return;
    final room = widget.online.room;
    if (room?.phase != RoomPhase.lightning) {
      _localPick = null;
      _resultPlayed = false;
      _hit = null;
      setState(() {});
      return;
    }
    final serverPick = room?.lightning?.picks[widget.online.clientId];
    if (serverPick != null) {
      _localPick = serverPick.$1;
      if (!_resultPlayed) {
        _resultPlayed = true;
        _playResult(serverPick.$2 > 0, serverPick.$2);
      }
    }
    setState(() {});
  }

  void _playResult(bool hit, int points) {
    _hit = hit;
    final feedback = GameFeedbackScope.of(context);
    if (hit) {
      feedback.play(Sfx.valid);
      feedback.haptic(Haptic.medium);
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) GameFeedbackScope.of(context).play(Sfx.points);
      });
    } else {
      feedback.play(Sfx.invalid);
      feedback.haptic(Haptic.heavy);
      _shake.forward(from: 0);
    }
  }

  void _pick(String option) {
    if (_localPick != null) return;
    setState(() => _localPick = option);
    widget.online.pickLightning(option);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = widget.online.room;
    final lightning = room?.lightning;
    if (room == null || lightning == null) {
      return Center(
        child: Text(
          l10n.lightningTitle,
          style: fredoka(size: 22, color: AppColors.white),
        ),
      );
    }

    final serverPick = lightning.picks[widget.online.clientId];
    final choice = serverPick?.$1 ?? _localPick;
    final points = serverPick?.$2;
    final left = room.until(lightning.endsAt);
    final victory = GameFeedbackScope.of(context).settings.victoryStyle;

    Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.lightningTitle,
                        style: fredoka(
                          size: 28,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                          shadows: textShadow,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InfoTip(
                        title: l10n.lightningTitle,
                        message: l10n.lightningInfoHelp,
                        okLabel: l10n.gotIt,
                        icon: GameIconKind.flame,
                        accent: AppColors.orange,
                        color: AppColors.white,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.lightningHelp(
                      lightning.category.label(l10n),
                      lightning.letter,
                      left.inSeconds,
                    ),
                    textAlign: TextAlign.center,
                    style: fredoka(size: 15, color: AppColors.white),
                  ),
                  if (_hit != null) ...[
                    const SizedBox(height: 12),
                    BounceIn(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _hit!
                              ? AppColors.green
                              : AppColors.red,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.25),
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _hit!
                              ? l10n.lightningHit(points ?? 0)
                              : l10n.lightningMiss,
                          textAlign: TextAlign.center,
                          style: fredoka(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _shake,
                    builder: (context, child) {
                      final t = _shake.value;
                      final dx = _hit == false
                          ? (1 - t) * 10 * ((t * 12).floor().isEven ? 1 : -1)
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final option in lightning.options)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CandyButton(
                              label: option,
                              color: choice == option
                                  ? (points == null
                                        ? AppColors.yellow
                                        : (points > 0
                                              ? AppColors.green
                                              : AppColors.red))
                                  : (choice != null
                                        ? AppColors.inkSoft
                                        : AppColors.purpleLight),
                              textColor: AppColors.white,
                              onPressed: choice == null
                                  ? () => _pick(option)
                                  : (choice == option ? () {} : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ReactionBar(online: widget.online),
        ],
      ),
    );

    if (_hit == true) {
      body = ConfettiOverlay(
        key: const ValueKey('lightning-hit'),
        pieces: 48,
        colors: victoryColors(victory),
        shape: victoryShapeFor(victory),
        child: body,
      );
    }

    return body;
  }
}

/// Bouton Freeze pendant la manche + achat.
class FreezeControls extends StatelessWidget {
  const FreezeControls({
    super.key,
    required this.online,
    required this.opponents,
  });

  final OnlineController online;
  final List<RoomPlayer> opponents;

  Future<void> _buy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final price = online.room?.freezePrice ?? 15;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.freezeBuyTitle),
        content: Text(l10n.freezeBuyHelp(price)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await online.buyFreeze();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage(l10n, e.code))),
        );
      }
    }
  }

  Future<void> _cast(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final me = online.me;
    if (me == null || me.freezesLeft < 1 || opponents.isEmpty) return;
    final target = await showModalBottomSheet<RoomPlayer>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.freezePickTarget,
                style: fredoka(size: 18, weight: FontWeight.w700),
              ),
            ),
            for (final p in opponents)
              ListTile(
                title: Text(p.nickname),
                subtitle: Text(p.frozen ? l10n.freezeAlready : ''),
                enabled: !p.frozen && !p.finished,
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    online.freezePlayer(target.clientId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = online.me;
    if (me == null) return const SizedBox.shrink();
    final frozen = me.frozen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (frozen)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.freezeYouAreFrozen,
              textAlign: TextAlign.center,
              style: fredoka(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: CandyButton(
                label: l10n.freezeUse(me.freezesLeft),
                icon: Icons.ac_unit_rounded,
                color: AppColors.cyan,
                textColor: AppColors.white,
                onPressed: me.freezesLeft < 1 || opponents.isEmpty
                    ? null
                    : () => _cast(context),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: CandyButton(
                label: '+',
                color: AppColors.orange,
                textColor: AppColors.white,
                fontSize: 28,
                onPressed: () => _buy(context),
              ),
            ),
            const SizedBox(width: 8),
            InfoTip(
              title: l10n.freezeBuyTitle,
              message: l10n.freezeInfoHelp,
              okLabel: l10n.gotIt,
              icon: GameIconKind.timer,
              accent: AppColors.cyan,
              color: AppColors.white,
              size: 28,
            ),
          ],
        ),
      ],
    );
  }
}

/// Revue des mots en fin de partie.
class WordReviewPanel extends StatelessWidget {
  const WordReviewPanel({super.key, required this.items});

  final List<WordReviewItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.wordReviewTitle,
              style: fredoka(
                size: 18,
                weight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 6),
            InfoTip(
              title: l10n.wordReviewTitle,
              message: l10n.wordReviewHelp,
              okLabel: l10n.gotIt,
              icon: GameIconKind.flag,
              accent: AppColors.yellow,
              color: AppColors.white,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in items.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.unique)
                      const Padding(
                        padding: EdgeInsets.only(right: 6, top: 2),
                        child: Text('⭐', style: TextStyle(fontSize: 14)),
                      ),
                    if (_flagSpecForReview(item) case final spec?) ...[
                      CountryFlag(spec: spec, width: 28),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        '${item.category.label(l10n)} · ${item.word}',
                        style: fredoka(
                          size: 15,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    if (item.by.isNotEmpty)
                      Flexible(
                        child: Text(
                          item.by.join(', '),
                          textAlign: TextAlign.right,
                          style: fredoka(size: 12, color: AppColors.yellow),
                        ),
                      ),
                  ],
                ),
                if (item.facts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      item.facts.join(' · '),
                      style: fredoka(
                        size: 12,
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Drapeau : pays directement, ou pays associé à une ville via les faits.
String? _flagSpecForReview(WordReviewItem item) {
  final country = switch (item.category) {
    Category.country => item.word,
    Category.city => _countryFromFacts(item.facts),
    _ => null,
  };
  if (country == null || country.isEmpty) return null;
  return flagSpecFor(country);
}

String? _countryFromFacts(List<String> facts) {
  for (final line in facts) {
    final lower = line.toLowerCase().trim();
    if (lower.startsWith('pays') || lower.startsWith('country')) {
      final idx = line.indexOf(':');
      if (idx < 0) continue;
      final name = line.substring(idx + 1).trim();
      if (name.isNotEmpty) return name;
    }
  }
  return null;
}

String roomTitleLabel(AppLocalizations l10n, String title) => switch (title) {
      'champion' => l10n.salonTitleChampion,
      'speedster' => l10n.salonTitleSpeedster,
      'rare_finder' => l10n.salonTitleRare,
      'dictionary' => l10n.salonTitleDictionary,
      _ => '',
    };
