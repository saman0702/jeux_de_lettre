import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/labels.dart';
import 'data/room_models.dart';
import 'data/saved_rooms.dart';
import 'online_controller.dart';
import 'widgets/online_header.dart';

String _when(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final m = MaterialLocalizations.of(context);
  return '${m.formatShortDate(local)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// Historique d'un salon gardé : parties jouées, conversation de groupe et
/// conversations privées du joueur.
class RoomHistoryScreen extends StatefulWidget {
  const RoomHistoryScreen({super.key, required this.code, this.apiClient});

  final String code;
  final ApiClient? apiClient;

  @override
  State<RoomHistoryScreen> createState() => _RoomHistoryScreenState();
}

class _RoomHistoryScreenState extends State<RoomHistoryScreen> {
  Future<RoomHistory>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= SavedRoomsApi(
      widget.apiClient ?? ApiClient(),
      OnlineScope.of(context).clientId,
    ).history(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = OnlineScope.of(context).clientId;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                OnlineHeader(
                  title: l10n.roomHistoryTitle(widget.code),
                  onBack: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 8),
                TabBar(
                  labelStyle: gameFont(size: 15, color: AppColors.white),
                  unselectedLabelStyle: fredoka(
                    size: 14,
                    color: AppColors.white,
                  ),
                  labelColor: AppColors.white,
                  unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
                  indicatorColor: AppColors.yellow,
                  tabs: [
                    Tab(text: l10n.historyGames),
                    Tab(text: l10n.historyGroup),
                    Tab(text: l10n.historyPrivate),
                  ],
                ),
                Expanded(
                  child: FutureBuilder<RoomHistory>(
                    future: _history,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _Empty(l10n.historyUnavailable);
                      }
                      final history = snapshot.data;
                      if (history == null) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.yellow,
                          ),
                        );
                      }
                      return TabBarView(
                        children: [
                          _GamesTab(games: history.games, me: me),
                          _MessagesList(
                            messages: history.group,
                            me: me,
                            empty: l10n.historyNoMessages,
                          ),
                          _PrivateTab(
                            history: history,
                            me: me,
                            code: widget.code,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: fredoka(size: 16, color: AppColors.white.withValues(alpha: 0.9)),
      ),
    ),
  );
}

class _GamesTab extends StatelessWidget {
  const _GamesTab({required this.games, required this.me});

  final List<RoomGameSummary> games;
  final String me;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (games.isEmpty) return _Empty(l10n.historyNoGames);
    return ListView.separated(
      key: const Key('history_games'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final game = games[i];
        return GameCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _when(context, game.finishedAt),
                      style: fredoka(size: 13, color: AppColors.inkSoft),
                    ),
                  ),
                  Text(
                    game.format == RoomFormat.elimination
                        ? l10n.formatElimination
                        : l10n.roundsCount(game.rounds),
                    style: fredoka(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final (rank, p) in game.ranking.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: rank < 3
                            ? GameIcon(GameIconKind.medal(rank + 1), size: 22)
                            : Text(
                                '${rank + 1}',
                                style: gameFont(size: 15, color: AppColors.ink),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          p.clientId == me
                              ? '${p.nickname} (${l10n.youBadge})'
                              : p.nickname,
                          style: fredoka(
                            size: 15,
                            weight: p.clientId == me
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        l10n.pointsShort(p.score),
                        style: gameFont(size: 15, color: AppColors.purple),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Liste de messages (groupe ou conversation privée), le plus récent en bas.
class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.messages,
    required this.me,
    required this.empty,
  });

  final List<RoomChatMessage> messages;
  final String me;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return _Empty(empty);
    return ListView(
      key: const Key('history_messages'),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        for (final m in messages.reversed)
          Align(
            alignment: m.clientId == me
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ChatBubble(
              message: m,
              mine: m.clientId == me,
              taggedMe: m.mentionsMe(me),
            ),
          ),
      ],
    );
  }
}

/// Bulle de message ; jaune quand le message me tague.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.mine,
    this.taggedMe = false,
  });

  final RoomChatMessage message;
  final bool mine;
  final bool taggedMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        color: taggedMe
            ? AppColors.yellow
            : mine
            ? AppColors.cyan.withValues(alpha: 0.9)
            : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x33140744), offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine)
            Text(
              message.nickname,
              style: gameFont(size: 13, color: AppColors.purple),
            ),
          Text(message.text, style: fredoka(size: 15, color: AppColors.ink)),
          if (message.at != null)
            Text(
              _when(context, message.at!),
              style: fredoka(size: 10, color: AppColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class _PrivateTab extends StatelessWidget {
  const _PrivateTab({
    required this.history,
    required this.me,
    required this.code,
  });

  final RoomHistory history;
  final String me;
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conversations = history.conversations(me);
    if (conversations.isEmpty) return _Empty(l10n.historyNoPrivate);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = conversations[i];
        return GestureDetector(
          key: Key('private_${c.otherId}'),
          onTap: () => Navigator.of(context).push(
            PopRoute(
              builder: (_) => PrivateChatScreen(
                code: code,
                otherId: c.otherId,
                otherName: c.otherName,
                initial: c.messages,
              ),
            ),
          ),
          child: GameCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const GameIcon(
                  GameIconKind.private,
                  size: 26,
                  color: AppColors.purple,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.otherName,
                        style: gameFont(size: 16, color: AppColors.ink),
                      ),
                      Text(
                        c.messages.last.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: fredoka(size: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Conversation privée avec un membre du salon. On peut écrire quand on est
/// dans le salon et que les messages privés sont débloqués.
class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.code,
    required this.otherId,
    required this.otherName,
    this.initial = const [],
  });

  final String code;
  final String otherId;
  final String otherName;
  final List<RoomChatMessage> initial;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _text = TextEditingController();
  late final List<RoomChatMessage> _messages = [...widget.initial];
  StreamSubscription<RoomChatMessage>? _incoming;
  bool _unlocking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final online = OnlineScope.of(context);
    _incoming ??= online.privateMessages.listen((m) {
      final pair = {m.clientId, m.to};
      if (pair.contains(widget.otherId) &&
          pair.contains(online.clientId) &&
          mounted) {
        setState(() => _messages.add(m));
      }
    });
  }

  @override
  void dispose() {
    _incoming?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _unlock(OnlineController online) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _unlocking = true);
    try {
      await online.unlockChat();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(l10n, e.code))));
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  void _send(OnlineController online) {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    online.sendPrivate(widget.otherId, text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: online,
            builder: (context, _) {
              final inRoom = online.room?.code == widget.code;
              final unlocked = online.me?.chatUnlocked ?? false;
              return Column(
                children: [
                  OnlineHeader(
                    title: widget.otherName,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: _MessagesList(
                      messages: _messages,
                      me: online.clientId,
                      empty: l10n.privateChatEmpty(widget.otherName),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: !inRoom
                        ? Text(
                            l10n.privateChatJoinRoom,
                            textAlign: TextAlign.center,
                            style: fredoka(size: 14, color: AppColors.white),
                          )
                        : !unlocked
                        ? FilledButton.icon(
                            key: const Key('unlock_private'),
                            onPressed: _unlocking
                                ? null
                                : () => _unlock(online),
                            icon: const Icon(Icons.lock_open_rounded),
                            label: Text(
                              l10n.privateChatUnlock(
                                online.room?.chatUnlockPrice ?? 25,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('private_text'),
                                  controller: _text,
                                  maxLength: 120,
                                  style: fredoka(
                                    size: 15,
                                    color: AppColors.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: l10n.privateChatHint(
                                      widget.otherName,
                                    ),
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.white,
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(online),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                key: const Key('private_send'),
                                onPressed: () => _send(online),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                ),
                                icon: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// « Mes salons » et salons publics fermés, dans l'écran des salons.
class SavedRoomsSection extends StatefulWidget {
  const SavedRoomsSection({
    super.key,
    required this.onOpen,
    this.apiClient,
    this.liveCodes = const {},
  });

  final ValueChanged<String> onOpen;
  final ApiClient? apiClient;

  /// Salons publics déjà listés en direct (on ne les répète pas).
  final Set<String> liveCodes;

  @override
  State<SavedRoomsSection> createState() => SavedRoomsSectionState();
}

class SavedRoomsSectionState extends State<SavedRoomsSection> {
  List<SavedRoomSummary> _mine = const [];
  List<SavedRoomSummary> _public = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mine.isEmpty && _public.isEmpty) refresh();
  }

  Future<void> refresh() async {
    final api = SavedRoomsApi(
      widget.apiClient ?? ApiClient(),
      OnlineScope.of(context).clientId,
    );
    final language = Localizations.localeOf(context).languageCode;
    try {
      final results = await Future.wait([api.mine(), api.public(language)]);
      if (!mounted) return;
      setState(() {
        _mine = results[0];
        _public = [
          for (final r in results[1])
            if (!r.mine) r,
        ];
      });
    } on ApiException {
      // Hors ligne : rien à montrer.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Text(text, style: gameFont(size: 20, color: AppColors.white)),
    );
    final public = [
      for (final r in _public)
        if (!widget.liveCodes.contains(r.code)) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mine.isNotEmpty) ...[
          title(l10n.myRoomsTitle),
          for (final r in _mine)
            _SavedRoomTile(room: r, onTap: () => widget.onOpen(r.code)),
        ],
        if (public.isNotEmpty) ...[
          title(l10n.allPublicRoomsTitle),
          for (final r in public)
            _SavedRoomTile(room: r, onTap: () => widget.onOpen(r.code)),
        ],
      ],
    );
  }
}

class _SavedRoomTile extends StatelessWidget {
  const _SavedRoomTile({required this.room, required this.onTap});

  final SavedRoomSummary room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        key: Key('saved_room_${room.code}'),
        onTap: onTap,
        child: GameCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GameIcon(
                room.public ? GameIconKind.public : GameIconKind.private,
                size: 28,
                color: AppColors.purple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.roomOf(room.creator)} · ${room.code}',
                      style: gameFont(size: 16, color: AppColors.ink),
                    ),
                    Text(
                      l10n.savedRoomInfo(
                        room.members,
                        _when(context, room.lastActivity),
                      ),
                      style: fredoka(size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: room.open ? AppColors.green : AppColors.cloud,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  room.open
                      ? l10n.savedRoomOpen(room.playersNow)
                      : l10n.savedRoomClosed,
                  style: gameFont(
                    size: 13,
                    color: room.open ? AppColors.white : AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
