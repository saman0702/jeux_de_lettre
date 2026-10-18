import 'dart:async';

import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';import '../../animations/transitions/pop_route.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/letter_race_logo.dart';
import '../../l10n/app_localizations.dart';
import '../career/career_screen.dart';
import '../career/elimination_screen.dart';
import '../game/solo_setup_screen.dart';
import '../game/widgets/labels.dart';
import '../online/data/room_models.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_counter.dart';
import '../avatar/avatar_screen.dart';
import '../online/widgets/player_avatar.dart';
import '../wallet/coin_counter.dart';
import '../wallet/level_badge.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  StreamSubscription<RoomSummary>? _publicRooms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameFeedbackScope.of(context).setMusic(MusicMood.menu);
      _publicRooms = OnlineScope.of(context).publicRooms.listen(_onPublicRoom);
    });
  }

  @override
  void dispose() {
    _publicRooms?.cancel();
    super.dispose();
  }

  void _onPublicRoom(RoomSummary room) {
    if (!mounted) return;
    if (OnlineScope.of(context).room != null) return;
    final l10n = AppLocalizations.of(context);
    final host = room.host.isEmpty ? '…' : room.host;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.publicRoomInvite(host)),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.joinPublicRoom,
            onPressed: () async {
              if (!await _readyForOnline() || !mounted) return;
              OnlineScope.of(context).joinRoom(room.code);
              Navigator.of(context).push(
                PopRoute(builder: (_) => const RoomScreen()),
              );
            },
          ),
        ),
      );
  }

  void _openSolo() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => SoloSetupScreen(apiClient: _api)));
  }

  void _openCareer() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => CareerScreen(apiClient: _api)));
  }

  void _openElimination() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => EliminationScreen(apiClient: _api)));
  }

  /// Les modes en ligne demandent une connexion et un pseudo.
  Future<bool> _readyForOnline() async {
    final online = OnlineScope.of(context);
    if (!online.isOnline) {
      online.client.connect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage(AppLocalizations.of(context), 'network_error'),
          ),
        ),
      );
      return false;
    }
    return ensureNickname(context);
  }

  Future<void> _quickMatch() async {
    if (!await _readyForOnline() || !mounted) return;
    OnlineScope.of(context)
        .quickMatch(Localizations.localeOf(context).languageCode);
    Navigator.of(context).push(PopRoute(builder: (_) => const RoomScreen()));
  }

  Future<void> _openRooms() async {
    if (!await _readyForOnline() || !mounted) return;
    Navigator.of(context).push(PopRoute(builder: (_) => const RoomsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Les boîtes de dialogue (pseudo, code) gèrent le clavier ; le menu ne
      // doit pas rétrécir.
      resizeToAvoidBottomInset: false,
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Rétrécit sur les petits écrans plutôt que de déborder.
                    // Prend toute la place libre : réglages et avatar restent
                    // à droite.
                    const Flexible(
                      fit: FlexFit.tight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            OnlineCounter(),
                            SizedBox(width: 8),
                            CoinCounter(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MyAvatarButton(
                      onTap: () => Navigator.of(context).push(
                        PopRoute(builder: (_) => AvatarScreen(apiClient: _api)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      key: const Key('settings_button'),
                      icon: Icons.settings_rounded,
                      tooltip: l10n.settingsTitle,
                      color: AppColors.yellow,
                      iconColor: AppColors.ink,
                      spinOnTap: true,
                      onPressed: () => showSettingsSheet(context),
                    ),
                  ],
                ),
                const Spacer(),
                const LetterRaceLogo(),
                const SizedBox(height: 20),
                BounceIn(
                  delay: const Duration(milliseconds: 900),
                  child: Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: fredoka(
                      size: 17,
                      color: AppColors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Carrière en grand, puis les autres modes deux par deux.
                BounceIn(
                  delay: const Duration(milliseconds: 700),
                  slideY: 0.6,
                  child: CandyButton(
                    key: const Key('mode_career'),
                    label: l10n.modeCareer,
                    gameIcon: GameIconKind.trophy,
                    color: AppColors.yellow,
                    onPressed: _openCareer,
                  ),
                ),
                const SizedBox(height: 12),
                for (final (row, buttons) in [
                  (
                    0,
                    [
                      (
                        l10n.modeFreeSolo,
                        GameIconKind.person,
                        AppColors.orange,
                        _openSolo,
                        'mode_solo',
                      ),
                      (
                        l10n.modeElimination,
                        GameIconKind.flag,
                        AppColors.pink,
                        _openElimination,
                        'mode_elimination',
                      ),
                    ],
                  ),
                  (
                    1,
                    [
                      (
                        l10n.modeQuickMatch,
                        GameIconKind.bolt,
                        AppColors.cyan,
                        _quickMatch,
                        'mode_quick',
                      ),
                      (
                        l10n.modeRooms,
                        GameIconKind.group,
                        AppColors.green,
                        _openRooms,
                        'mode_rooms',
                      ),
                    ],
                  ),
                ]) ...[
                  Row(
                    children: [
                      for (final (i, (label, icon, color, onPressed, key))
                          in buttons.indexed) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: BounceIn(
                            delay: Duration(
                              milliseconds: 820 + row * 120 + i * 60,
                            ),
                            slideY: 0.6,
                            child: CandyButton(
                              key: Key(key),
                              label: label,
                              gameIcon: icon,
                              color: color,
                              textColor: color == AppColors.green
                                  ? AppColors.white
                                  : AppColors.ink,
                              onPressed: onPressed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mon avatar en haut de l'accueil ; ouvre le choix d'avatar.
class _MyAvatarButton extends StatelessWidget {
  const _MyAvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = OnlineScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.avatarTitle,
      child: GestureDetector(
        key: const Key('avatar_button'),
        onTap: onTap,
        child: ListenableBuilder(
          listenable: online,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatar(
                nickname: '',
                seed: online.clientId,
                size: 46,
                preset: online.avatarPreset,
                photoUrl: online.avatarUrl,
                frame: online.look.frame,
                hair: online.look.hair,
                hat: online.look.hat,
              ),
              Positioned(
                right: -6,
                bottom: -4,
                child: LevelBadge(level: online.level),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
