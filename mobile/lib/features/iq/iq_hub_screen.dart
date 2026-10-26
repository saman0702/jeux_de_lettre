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
import '../online/data/room_models.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_header.dart';
import 'game_hub_screen.dart';
import 'iq_setup_screen.dart';

/// Espace QI : créer ou rejoindre un salon, jouer seul ou contre les bots.
class IqHubScreen extends StatefulWidget {
  const IqHubScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<IqHubScreen> createState() => _IqHubScreenState();
}

class _IqHubScreenState extends State<IqHubScreen> {
  OnlineController? _online;

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

  /// Au retour d'un salon, on se réabonne à la liste des salons ouverts.
  void _rewatch() {
    if (mounted) {
      _online?.watchRooms(Localizations.localeOf(context).languageCode);
    }
  }

  Future<void> _openRoom() async {
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
    _rewatch();
  }

  Future<void> _setup(IqSetupMode mode) async {
    final online = mode != IqSetupMode.solo;
    if (online && (!await readyForOnline(context) || !mounted)) return;
    // Les réglages ouvrent ensuite le salon ou la partie solo à leur place.
    await Navigator.of(context).push(
      PopRoute(
        builder: (_) => IqSetupScreen(mode: mode, apiClient: widget.apiClient),
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
        child: SafeArea(
          child: ListenableBuilder(
            listenable: online,
            builder: (context, _) {
              final rooms = [
                for (final r in online.rooms)
                  if (r.game == RoomGame.iq) r,
              ];
              return FloatingBarsLayout(
                header: OnlineHeader(
                  title: l10n.iqTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                children: [
                  const SizedBox(height: 8),
                  CandyButton(
                    key: const Key('iq_create'),
                    label: l10n.iqCreateRoom,
                    icon: Icons.add_rounded,
                    color: AppColors.purpleLight,
                    textColor: AppColors.white,
                    onPressed: () => _setup(IqSetupMode.room),
                  ),
                  const SizedBox(height: 12),
                  CandyButton(
                    key: const Key('iq_join'),
                    label: l10n.joinWithCode,
                    icon: Icons.vpn_key_rounded,
                    color: AppColors.white,
                    height: 48,
                    fontSize: 17,
                    onPressed: () => _join(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CandyButton(
                          key: const Key('iq_solo'),
                          label: l10n.iqSolo,
                          gameIcon: GameIconKind.person,
                          color: AppColors.yellow,
                          height: 48,
                          fontSize: 16,
                          onPressed: () => _setup(IqSetupMode.solo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CandyButton(
                          key: const Key('iq_bots'),
                          label: l10n.iqBots,
                          gameIcon: GameIconKind.bot,
                          color: AppColors.cyan,
                          height: 48,
                          fontSize: 16,
                          onPressed: () => _setup(IqSetupMode.bots),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                    child: Text(
                      l10n.iqOpenRooms,
                      style: gameFont(size: 18, color: AppColors.white),
                    ),
                  ),
                  if (rooms.isEmpty)
                    Text(
                      l10n.iqNoRooms,
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
                          key: Key('iq_room_${room.code}'),
                          onTap: () => _join(room.code),
                          child: GameCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const GameIcon(
                                  GameIconKind.hint,
                                  size: 28,
                                  color: AppColors.purple,
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
