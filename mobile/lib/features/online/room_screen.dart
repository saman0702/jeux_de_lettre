import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/countdown/countdown_view.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/hints/hint_controller.dart';
import '../game/widgets/round_view.dart';
import 'data/room_models.dart';
import 'online_controller.dart';
import 'widgets/lobby_view.dart';
import 'widgets/online_header.dart';
import 'widgets/podium_view.dart';
import 'widgets/room_results_view.dart';
import 'widgets/salon_social.dart';
import '../perks/perks_controller.dart';
import '../../animations/transitions/pop_route.dart';
import 'room_history.dart';
import 'widgets/players_strip.dart';
import 'widgets/round_wait_view.dart';
import 'widgets/searching_view.dart';
import 'widgets/voice_bridge.dart';
import 'voice/voice_session.dart';
import '../../core/widgets/game_icon.dart';

/// La salle où se trouve le joueur, quelle que soit sa phase. Ouverte juste
/// après avoir demandé une salle au serveur (partie rapide, création,
/// rejoindre).
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    this.tick = const Duration(milliseconds: 200),
    this.now = DateTime.now,
  });

  /// Fréquence de rafraîchissement des comptes à rebours ; injectable dans les
  /// tests avec [now].
  final Duration tick;
  final DateTime Function() now;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late OnlineController _online;
  late GameFeedback _feedback;
  final List<StreamSubscription> _subscriptions = [];
  Timer? _ticker;

  final Map<Category, TextEditingController> _fields = {};
  int? _fieldsRound;
  HintController? _hints;
  int? _submittedRound;

  /// Le podium final reste à l'écran jusqu'au choix du joueur, même si
  /// quelqu'un a déjà relancé la salle.
  List<RoomPlayer>? _podium;
  int _podiumStake = 0;
  bool _podiumPrize = false;
  String _podiumHostId = '';
  Map<String, int> _podiumWinnings = const {};
  bool _left = false;

  /// Renseigné dès qu'une demande de salle a été vue, pour qu'une demande
  /// échouée ferme l'écran.
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _online = OnlineScope.of(context);
    _feedback = GameFeedbackScope.of(context);
    _perks ??= PerksScope.maybeOf(context);
    if (_online.room != null || _online.searching) _active = true;
    if (_subscriptions.isEmpty) {
      _subscriptions
        ..add(_online.notices.listen(_showNotice))
        ..add(_online.mentions.listen(_showMention))
        ..add(_online.errors.listen(_showError));
      _online.addListener(_onRoomChanged);
      _ticker = Timer.periodic(widget.tick, (_) => _onTick());
    }
  }

  @override
  void dispose() {
    if (_podium != null) _perks?.onGameFinished();
    _ticker?.cancel();
    _online.removeListener(_onRoomChanged);
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final f in _fields.values) {
      f.dispose();
    }
    _hints?.dispose();
    _feedback.setMusic(MusicMood.menu);
    if (!_left && _online.room != null) {
      // Pas pendant le démontage de l'arbre : quitter la salle prévient
      // d'autres écrans.
      final online = _online;
      Future.microtask(online.leaveRoom);
    }
    super.dispose();
  }

  RoomState? get _room => _online.room;

  void _onRoomChanged() {
    final room = _room;
    if (room != null || _online.searching) _active = true;
    if (room == null) {
      // Erreur du serveur pendant la recherche (ex. salle pleine) : retour au
      // menu.
      if (_active && !_online.searching && !_left && mounted) _close();
      return;
    }
    if (room.phase == RoomPhase.finished && _podium == null) {
      _podium = room.ranking;
      _podiumStake = room.settings.stake;
      _podiumPrize = room.settings.prize;
      _podiumHostId = room.hostId;
      _podiumWinnings = room.winnings;
    }
    // Contre des bots, musique électronique ; entre humains, musique de salon.
    // Plus bas pendant le décompte et la manche.
    _feedback.setMusic(
      room.players.any((p) => p.bot) ? MusicMood.bots : MusicMood.room,
      quiet: room.phase == RoomPhase.countdown || room.phase == RoomPhase.round,
    );
    final round = room.round;
    if (room.phase == RoomPhase.round &&
        round != null &&
        _fieldsRound != round.number) {
      final me = room.player(_online.clientId);
      final cats =
          room.settings.relay && me != null && me.assignments.isNotEmpty
          ? me.assignments
          : room.settings.categories;
      _prepareFields(cats, round.number);
    }
    // Fin de partie : si une revanche a démarré, on quitte le podium.
    if (_podium != null &&
        room.phase != RoomPhase.finished &&
        room.phase != RoomPhase.results) {
      _leavePodium();
    }
    if (mounted) setState(() {});
  }

  void _prepareFields(List<Category> categories, int round) {
    for (final c in categories) {
      (_fields[c] ??= TextEditingController()).clear();
    }
    _fields.removeWhere((c, f) => !categories.contains(c));
    _fieldsRound = round;
    _hints?.dispose();
    _hints = HintController(
      source: _OnlineHintSource(_online, round),
      hintsLeft: _online.me?.hintsLeft ?? 0,
      letter: _room?.round?.letter ?? '',
    );
  }

  void _onTick() {
    final room = _room;
    if (room == null || !mounted) return;
    final round = room.round;
    if (room.phase == RoomPhase.round &&
        round != null &&
        _canAnswer(room) &&
        round.remaining(widget.now()) == Duration.zero) {
      _submit();
    }
    // Les comptes à rebours (début de partie rapide, 3-2-1, chrono, manche
    // suivante) suivent l'horloge.
    setState(() {});
  }

  bool _canAnswer(RoomState room) {
    final me = room.player(_online.clientId);
    return me != null &&
        me.playing &&
        !me.finished &&
        _submittedRound != room.round?.number;
  }

  void _submit() {
    final round = _room?.round;
    if (round == null || _submittedRound == round.number) return;
    _submittedRound = round.number;
    _online.submit(round.number, {
      for (final e in _fields.entries) e.key: e.value.text.trim(),
    });
    setState(() {});
  }

  void _showNotice(RoomNotice notice) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final inGame =
        _room != null &&
        _room!.phase != RoomPhase.waiting &&
        _room!.phase != RoomPhase.finished;
    final text = switch (notice.kind) {
      NoticeKind.joined => l10n.noticeJoined(notice.nickname),
      NoticeKind.left =>
        inGame
            ? l10n.noticeLeftGame(notice.nickname)
            : l10n.noticeLeft(notice.nickname),
      NoticeKind.disconnected => l10n.noticeDisconnected(notice.nickname),
      NoticeKind.reconnected => l10n.noticeReconnected(notice.nickname),
      NoticeKind.botsJoined => l10n.noticeBotsJoined,
      NoticeKind.hintUsed => () {
        var category = notice.detail;
        try {
          category = Category.fromWire(notice.detail).label(l10n);
        } catch (_) {}
        return l10n.noticeHintUsed(notice.nickname, category);
      }(),
      NoticeKind.error => l10n.errorGeneric,
    };
    final important =
        notice.kind == NoticeKind.left ||
        notice.kind == NoticeKind.disconnected ||
        notice.kind == NoticeKind.hintUsed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: TextStyle(
              fontWeight: important ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          duration: Duration(seconds: important ? 5 : 2),
          backgroundColor: important ? const Color(0xFFE85D4C) : null,
        ),
      );
  }

  void _showError(String code) {
    if (!mounted) return;
    // Envoi refusé : on annule le flag local pour ne pas rester « en attente »
    // avec une fausse icône crayon / check.
    if (code == 'round_not_current') {
      _submittedRound = null;
      setState(() {});
    }
    if (code == 'round_already_submitted' || code == 'round_over') return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage(AppLocalizations.of(context), code))),
    );
  }

  void _close() {
    if (_left) return;
    _left = true;
    unawaited(VoiceSession.instance.resetForRoomLeave());
    if (_online.room != null || _online.searching) _online.leaveRoom();
    // pop() et non maybePop() : la garde PopScope redemanderait confirmation.
    Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final room = _room;
    final inGame =
        room != null &&
        room.phase != RoomPhase.waiting &&
        room.phase != RoomPhase.finished;
    if (!inGame) return _close();

    final l10n = AppLocalizations.of(context);
    final leave = await showGameConfirm(
      context,
      icon: GameIconKind.door,
      title: l10n.quitGameTitle,
      message: l10n.leaveRoomMessage,
      confirmLabel: l10n.quit.toUpperCase(),
      cancelLabel: l10n.dialogStay,
    );
    if (leave && mounted) _close();
  }

  PerksController? _perks;

  /// Quelqu'un m'a tagué dans la discussion du salon.
  void _showMention(String from) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).chatMentionedBy(from)),
        action: SnackBarAction(
          label: AppLocalizations.of(context).roomChatButton,
          onPressed: () => showRoomChatSheet(context, _online),
        ),
      ),
    );
  }

  /// On quitte le podium : une pub peut passer, selon les options du serveur.
  void _leavePodium() {
    if (_podium != null) _perks?.onGameFinished();
    _podium = null;
  }

  void _playAgain() {
    // Vote revanche : le podium reste jusqu'au quorum, puis le lobby reprend.
    _online.voteRematch(true);
  }

  void _startBonus() {
    setState(_leavePodium);
    _online.startBonus();
  }

  bool _showingPodium(RoomState? room) =>
      _podium != null &&
      (room == null ||
          room.phase == RoomPhase.finished ||
          room.phase == RoomPhase.results);

  /// Partie en cours (pas lobby / podium) → icône quitter.
  bool _inGame(RoomState? room) {
    if (room == null || _showingPodium(room)) return false;
    return room.phase != RoomPhase.waiting;
  }

  String _headerTitle(AppLocalizations l10n, RoomState? room) {
    if (_showingPodium(room)) return l10n.podiumTitle;
    if (room == null) return l10n.modeQuickMatch;
    if (room.phase == RoomPhase.waiting) {
      return room.quick
          ? l10n.modeQuickMatch
          : l10n.roomOf(room.player(room.hostId)?.nickname ?? '');
    }
    final bonus = room.round?.bonus == true;
    if (bonus) return l10n.bonusRound;
    final n = room.phase == RoomPhase.countdown
        ? room.roundNumber + 1
        : (room.results?.number ?? room.round?.number ?? room.roundNumber);
    if (n > 0) return l10n.roundProgress(n, room.settings.rounds);
    return room.quick
        ? l10n.modeQuickMatch
        : l10n.roomOf(room.player(room.hostId)?.nickname ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = _room;
    final inGame = _inGame(room);

    return PopScope(
      canPop: _left,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: GameBackground(
          palette: _palette(room),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    OnlineHeader(
                      title: _headerTitle(l10n, room),
                      onBack: _confirmLeave,
                      quitStyle: inGame,
                    ),
                    if (!_online.isOnline) const _ConnectionBanner(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween(
                              begin: 0.94,
                              end: 1.0,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_phaseKey(room)),
                          child: _buildPhase(room),
                        ),
                      ),
                    ),
                  ],
                ),
                if (room != null && room.voice.enabled && room.voice.open) ...[
                  VoiceBridge(online: _online, room: room),
                  // Sur le podium, les FAB audio sont dans PodiumView (alignés
                  // au chat). Pendant la manche : en haut à droite.
                  if (!_showingPodium(room))
                    if (room.phase == RoomPhase.round)
                      Positioned(
                        right: 12,
                        top: 8,
                        child: VoiceFab(
                          online: _online,
                          room: room,
                          compact: true,
                        ),
                      )
                    else
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: VoiceFab(online: _online, room: room),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  BackgroundPalette _palette(RoomState? room) {
    if (_podium != null) return BackgroundPalette.victory;
    if (room == null || room.phase == RoomPhase.waiting) {
      return BackgroundPalette.menu;
    }
    if (room.phase == RoomPhase.finished) return BackgroundPalette.victory;
    final number = room.phase == RoomPhase.countdown
        ? room.roundNumber + 1
        : room.roundNumber;
    return BackgroundPalette.forRound(number);
  }

  String _phaseKey(RoomState? room) {
    if (_podium != null) return 'podium';
    if (room == null) return 'searching';
    return switch (room.phase) {
      RoomPhase.round => 'round-${room.round?.number}-${_canAnswer(room)}',
      RoomPhase.results => 'results-${room.results?.number}',
      final phase => phase.name,
    };
  }

  Future<void> _report(RoomPlayer player) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showGameConfirm(
      context,
      icon: GameIconKind.flag,
      title: l10n.reportTitle,
      message: l10n.reportMessage(player.nickname),
      confirmLabel: l10n.reportConfirm,
      cancelLabel: l10n.cancel,
    );
    if (!confirmed) return;
    _online.reportPlayer(player.clientId);
    messenger.showSnackBar(SnackBar(content: Text(l10n.reportSent)));
  }

  Widget _buildPhase(RoomState? room) {
    final podium = _podium;
    if (_showingPodium(room) && podium != null) {
      return PodiumView(
        ranking: podium,
        myId: _online.clientId,
        onPlayAgain: _playAgain,
        stake: _podiumStake,
        prize: _podiumPrize,
        hostId: _podiumHostId,
        winnings: _podiumWinnings,
        room: room,
        online: _online,
        onBonus: room != null && !room.bonusPlayed ? _startBonus : null,
      );
    }
    if (room == null) return SearchingView(onCancel: _close);

    switch (room.phase) {
      case RoomPhase.waiting:
        final isHost = room.hostId == _online.clientId && !room.quick;
        return LobbyView(
          room: room,
          myId: _online.clientId,
          onReady: _online.setReady,
          // Pas de bots dans un salon de paris.
          onAddBot: isHost && !room.settings.betting ? _online.addBot : null,
          onRemoveBot: isHost ? _online.removeBot : null,
          onReport: _report,
          onOpenChat: () => showRoomChatSheet(context, _online),
          onOpenHistory: () => Navigator.of(context).push(
            PopRoute(builder: (_) => RoomHistoryScreen(code: room.code)),
          ),
        );
      case RoomPhase.finished:
        // Géré par le podium ci-dessus.
        return const SizedBox.shrink();
      case RoomPhase.countdown:
        final seconds =
            (room.until(room.goAt, widget.now()).inMilliseconds / 1000).ceil();
        return Stack(
          children: [
            CountdownView(value: seconds.clamp(0, 3)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: PlayersStrip(
                room: room,
                myId: _online.clientId,
                showProgress: false,
              ),
            ),
          ],
        );
      case RoomPhase.lightning:
        return LightningView(online: _online);
      case RoomPhase.round:
        final round = room.round!;
        final me = room.player(_online.clientId);
        final localDone = {
          if (_submittedRound == round.number) _online.clientId,
        };
        if (_canAnswer(room)) {
          final opponents = [
            for (final p in room.players)
              if (p.clientId != _online.clientId &&
                  p.playing &&
                  !p.finished &&
                  !localDone.contains(p.clientId) &&
                  !p.eliminated)
                p,
          ];
          return RoundView(
            round: round,
            totalRounds: room.round?.bonus == true ? 1 : room.settings.rounds,
            remaining: round.remaining(widget.now()),
            fields: _fields,
            onFinish: me?.frozen == true ? () {} : _submit,
            hints: _hints,
            players: PlayersStrip(
              room: room,
              myId: _online.clientId,
              forceFinishedIds: localDone,
            ),
            footer: FreezeControls(online: _online, opponents: opponents),
          );
        }
        return Column(
          children: [
            const SizedBox(height: 8),
            PlayersStrip(
              room: room,
              myId: _online.clientId,
              forceFinishedIds: localDone,
            ),
            Expanded(
              child: RoundWaitView(
                room: room,
                myId: _online.clientId,
                spectating: !(me?.playing ?? false),
                eliminated: me?.eliminated ?? false,
              ),
            ),
          ],
        );
      case RoomPhase.results:
        return Column(
          children: [
            const SizedBox(height: 8),
            PlayersStrip(
              room: room,
              myId: _online.clientId,
              showProgress: false,
            ),
            Expanded(
              child: RoomResultsView(room: room, myId: _online.clientId),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ReactionBar(online: _online),
            ),
          ],
        );
    }
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GameIcon(GameIconKind.offline, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppLocalizations.of(context).connectionLost,
              style: fredoka(
                size: 15,
                weight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineHintSource implements HintSource {
  _OnlineHintSource(this._online, this._round);

  final OnlineController _online;
  final int _round;

  @override
  bool get canBuyExtra => true;

  @override
  Future<HintOptions> request(Category category, {bool reveal = false}) =>
      _online.requestHint(_round, category, reveal: reveal);

  @override
  Future<HintPick> pick(Category category, String choice) =>
      _online.pickHint(_round, category, choice);

  @override
  Future<BuyHintResult> buyExtra() => _online.buyHint();
}
