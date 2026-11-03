import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../iq/game_hub_screen.dart';
import '../online/data/room_models.dart';
import '../online/online_controller.dart';
import '../online/room_history.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_header.dart';
import 'quiz_models.dart';
import 'quiz_setup_screen.dart';

/// Hub salons pour Chrono ou Mot & Sens (créer, code, bots, liste).
class QuizRoomsHubScreen extends StatefulWidget {
  const QuizRoomsHubScreen({
    super.key,
    required this.game,
    required this.title,
    required this.soloTitle,
    required this.theme,
    required this.accent,
    required this.questions,
    this.apiClient,
  });

  final RoomGame game;
  final String title;
  final String soloTitle;
  final BackgroundTheme theme;
  final Color accent;
  final List<QuizQuestion> questions;
  final ApiClient? apiClient;

  @override
  State<QuizRoomsHubScreen> createState() => _QuizRoomsHubScreenState();
}

class _QuizRoomsHubScreenState extends State<QuizRoomsHubScreen> {
  OnlineController? _online;
  final _saved = GlobalKey<SavedRoomsSectionState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_online == null) {
      _online = OnlineScope.of(context);
      _online!.watchRooms(Localizations.localeOf(context).languageCode);
    }
  }

  @override
  void dispose() {
    _online?.unwatchRooms();
    super.dispose();
  }

  void _rewatch() {
    if (mounted) {
      _online?.watchRooms(Localizations.localeOf(context).languageCode);
      _saved.currentState?.refresh();
    }
  }

  Future<void> _openRoom() async {
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
    _rewatch();
  }

  Future<void> _setup(QuizSetupMode mode) async {
    if (!await readyForOnline(context) || !mounted) return;
    await Navigator.of(context).push(
      PopRoute(
        builder: (_) => QuizSetupScreen(
          mode: mode,
          game: widget.game,
          title: widget.title,
          soloTitle: widget.soloTitle,
          theme: widget.theme,
          accent: widget.accent,
          questions: widget.questions,
        ),
      ),
    );
    _rewatch();
  }

  Future<void> _join([String? known]) async {
    if (!await readyForOnline(context) || !mounted) return;
    final code = known ?? await askRoomCode(context);
    if (code == null || !mounted) return;
    OnlineScope.of(context).joinRoom(code);
    await _openRoom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);
    return Scaffold(
      body: GameBackground(
        theme: widget.theme,
        palette: BackgroundPalette.history,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: online,
            builder: (context, _) {
              final rooms = [
                for (final r in online.rooms)
                  if (r.game == widget.game) r,
              ];
              return FloatingBarsLayout(
                header: OnlineHeader(
                  title: widget.title,
                  onBack: () => Navigator.of(context).pop(),
                ),
                children: [
                  const SizedBox(height: 8),
                  CandyButton(
                    key: const Key('quiz_create'),
                    label: l10n.quizCreateRoom,
                    icon: Icons.add_rounded,
                    color: widget.accent,
                    textColor: AppColors.white,
                    height: 48,
                    fontSize: 17,
                    onPressed: () => _setup(QuizSetupMode.room),
                  ),
                  const SizedBox(height: 12),
                  CandyButton(
                    key: const Key('quiz_join'),
                    label: l10n.joinWithCode,
                    icon: Icons.vpn_key_rounded,
                    color: AppColors.white,
                    height: 48,
                    fontSize: 17,
                    onPressed: () => _join(),
                  ),
                  const SizedBox(height: 12),
                  CandyButton(
                    key: const Key('quiz_bots'),
                    label: l10n.iqBots,
                    gameIcon: GameIconKind.bot,
                    color: AppColors.sage,
                    height: 48,
                    fontSize: 16,
                    onPressed: () => _setup(QuizSetupMode.bots),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                    child: Text(
                      l10n.quizOpenRooms,
                      style: gameFont(size: 18, color: AppColors.white),
                    ),
                  ),
                  if (rooms.isEmpty)
                    Text(
                      l10n.quizNoRooms,
                      textAlign: TextAlign.center,
                      style: fredoka(
                        size: 15,
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    )
                  else
                    for (final room in rooms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          key: Key('quiz_room_${room.code}'),
                          onTap: () => _join(room.code),
                          child: GameCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                GameIcon(
                                  GameIconKind.hint,
                                  size: 28,
                                  color: widget.accent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.roomOf(room.host),
                                    style: gameFont(
                                      size: 16,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  l10n.playersCount(
                                    room.players,
                                    room.maxPlayers,
                                  ),
                                  style: gameFont(
                                    size: 15,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  SavedRoomsSection(
                    key: _saved,
                    apiClient: widget.apiClient,
                    game: widget.game,
                    onOpen: (code) => _join(code),
                    liveCodes: {for (final r in rooms) r.code},
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
