import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/countdown/countdown_view.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/quit_button.dart';
import '../game/hints/hint_controller.dart';
import '../game/widgets/round_view.dart';
import 'data/room_models.dart';
import 'online_controller.dart';
import 'widgets/lobby_view.dart';
import 'widgets/online_header.dart';
import 'widgets/podium_view.dart';
import 'widgets/room_results_view.dart';
import 'widgets/round_wait_view.dart';
import 'widgets/searching_view.dart';
import '../../core/widgets/game_icon.dart';

/// The room the player is in, whatever its phase. Pushed right after asking
/// the server for a room (quick match, create, join).
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    this.tick = const Duration(milliseconds: 200),
    this.now = DateTime.now,
  });

  /// Refresh rate of the countdowns; injectable for tests along with [now].
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

  /// The final podium stays on screen until the player chooses, even if
  /// someone else already restarted the room.
  List<RoomPlayer>? _podium;
  bool _left = false;

  /// Set once a room request was seen, so a failed request closes the screen.
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _online = OnlineScope.of(context);
    _feedback = GameFeedbackScope.of(context);
    if (_online.room != null || _online.searching) _active = true;
    if (_subscriptions.isEmpty) {
      _subscriptions
        ..add(_online.notices.listen(_showNotice))
        ..add(_online.errors.listen(_showError));
      _online.addListener(_onRoomChanged);
      _ticker = Timer.periodic(widget.tick, (_) => _onTick());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _online.removeListener(_onRoomChanged);
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final f in _fields.values) {
      f.dispose();
    }
    _hints?.dispose();
    _feedback.musicWanted = true;
    if (!_left && _online.room != null) {
      // Not during the tree teardown: leaving notifies other screens.
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
      // Server-side error while searching (e.g. room full): back to the menu.
      if (_active && !_online.searching && !_left && mounted) _close();
      return;
    }
    if (room.phase == RoomPhase.finished && _podium == null) {
      _podium = room.ranking;
    }
    _feedback.musicWanted =
        room.phase == RoomPhase.waiting || room.phase == RoomPhase.finished;
    final round = room.round;
    if (room.phase == RoomPhase.round &&
        round != null &&
        _fieldsRound != round.number) {
      _prepareFields(room.settings.categories, round.number);
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
    // Countdowns (quick match start, 3-2-1, timer, next round) follow the clock.
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
    final text = switch (notice.kind) {
      NoticeKind.joined => l10n.noticeJoined(notice.nickname),
      NoticeKind.left => l10n.noticeLeft(notice.nickname),
      NoticeKind.disconnected => l10n.noticeDisconnected(notice.nickname),
      NoticeKind.reconnected => l10n.noticeReconnected(notice.nickname),
      NoticeKind.botsJoined => l10n.noticeBotsJoined,
      NoticeKind.error => l10n.errorGeneric,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
  }

  void _showError(String code) {
    if (!mounted) return;
    // Errors about stale rounds are harmless (e.g. a submit right at the buzzer).
    if (code.startsWith('round_')) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage(AppLocalizations.of(context), code))),
    );
  }

  void _close() {
    if (_left) return;
    _left = true;
    if (_online.room != null || _online.searching) _online.leaveRoom();
    // pop(), not maybePop(): the PopScope guard would ask to confirm again.
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

  void _playAgain() {
    setState(() => _podium = null);
    _online.setReady(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = _room;

    return PopScope(
      canPop: _left,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        body: GameBackground(
          palette: _palette(room),
          focusLetter: room?.phase == RoomPhase.round
              ? room?.round?.letter
              : null,
          child: SafeArea(
            child: Column(
              children: [
                if (room == null || room.phase == RoomPhase.waiting)
                  OnlineHeader(
                    title: room == null
                        ? l10n.modeQuickMatch
                        : room.quick
                        ? l10n.modeQuickMatch
                        : l10n.roomOf(room.player(room.hostId)?.nickname ?? ''),
                    onBack: _confirmLeave,
                  ),
                if (!_online.isOnline) const _ConnectionBanner(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.94, end: 1.0).animate(animation),
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

  Widget _buildPhase(RoomState? room) {
    final podium = _podium;
    if (podium != null) {
      return PodiumView(
        ranking: podium,
        myId: _online.clientId,
        onPlayAgain: _playAgain,
        onLeave: _close,
      );
    }
    if (room == null) return SearchingView(onCancel: _close);

    switch (room.phase) {
      case RoomPhase.waiting:
      case RoomPhase.finished:
        final isHost = room.hostId == _online.clientId && !room.quick;
        return LobbyView(
          room: room,
          myId: _online.clientId,
          onReady: _online.setReady,
          onAddBot: isHost ? _online.addBot : null,
          onRemoveBot: isHost ? _online.removeBot : null,
        );
      case RoomPhase.countdown:
        final seconds =
            (room.until(room.goAt, widget.now()).inMilliseconds / 1000).ceil();
        return WithQuitButton(
          onQuit: _confirmLeave,
          child: CountdownView(value: seconds.clamp(0, 3)),
        );
      case RoomPhase.round:
        final round = room.round!;
        final me = room.player(_online.clientId);
        if (_canAnswer(room)) {
          return RoundView(
            round: round,
            totalRounds: room.settings.rounds,
            remaining: round.remaining(widget.now()),
            fields: _fields,
            onFinish: _submit,
            hints: _hints,
            onQuit: _confirmLeave,
          );
        }
        return WithQuitButton(
          onQuit: _confirmLeave,
          child: RoundWaitView(room: room, spectating: !(me?.playing ?? false)),
        );
      case RoomPhase.results:
        return WithQuitButton(
          onQuit: _confirmLeave,
          child: RoomResultsView(room: room, myId: _online.clientId),
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
  Future<HintOptions> request(Category category) =>
      _online.requestHint(_round, category);

  @override
  Future<HintPick> pick(Category category, String choice) =>
      _online.pickHint(_round, category, choice);
}
