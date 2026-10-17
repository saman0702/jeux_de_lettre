import 'package:flutter/material.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/challenge.dart';
import '../game/solo_launcher.dart';
import '../game/data/models.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../../animations/transitions/pop_route.dart';
import '../game/widgets/labels.dart';
import '../online/data/room_models.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_header.dart';

/// Éliminatoires en solo : règles, record, et départ.
class EliminationScreen extends StatefulWidget {
  const EliminationScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<EliminationScreen> createState() => _EliminationScreenState();
}

class _EliminationScreenState extends State<EliminationScreen> {
  bool _loading = false;
  Difficulty _difficulty = Difficulty.normal;

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    const challenge = EliminationChallenge();
    final started = await launchSoloGame(
      context,
      apiClient: widget.apiClient,
      settings: challenge.settings(
        Localizations.localeOf(context).languageCode,
        GameFeedbackScope.of(context).settings.nickname ?? l10n.defaultNickname,
        OnlineScope.of(context).clientId,
        difficulty: _difficulty,
      ),
      challenge: challenge,
      replace: false,
    );
    if (mounted) setState(() => _loading = false);
    if (!started) return;
  }

  /// En ligne avec des amis : il faut être connecté et avoir un pseudo.
  Future<bool> _readyForFriends() async {
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

  /// Ouvre tout de suite un salon éliminatoires : le code se partage depuis
  /// la salle, comme pour un salon classique.
  Future<void> _invite() async {
    if (!await _readyForFriends() || !mounted) return;
    OnlineScope.of(context).createRoom(
      RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _difficulty,
        rounds: EliminationChallenge.rounds,
        roundDuration: EliminationChallenge.roundDuration,
        format: RoomFormat.elimination,
      ),
    );
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
  }

  Future<void> _joinFriend() async {
    if (!await _readyForFriends() || !mounted) return;
    final code = await askRoomCode(context);
    if (code == null || !mounted) return;
    OnlineScope.of(context).joinRoom(code);
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final best = GameFeedbackScope.of(context).settings.eliminationBest;
    const challenge = EliminationChallenge();
    // Paliers du minimum : (première manche, dernière manche, points).
    const steps = [(1, 3), (4, 7), (8, 11), (12, 15)];

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: l10n.modeElimination,
              onBack: () => Navigator.of(context).pop(),
            ),
            footerHeight: 118,
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: CandyButton(
                key: const Key('start_elimination'),
                label: l10n.playAlone,
                icon: Icons.play_arrow_rounded,
                color: AppColors.green,
                textColor: AppColors.white,
                loading: _loading,
                onPressed: _start,
              ),
            ),
            children: [
              OptionSection(
                index: 0,
                title: l10n.eliminationBestTitle,
                icon: GameIconKind.trophy,
                color: AppColors.yellow,
                child: Text(
                  best == 0
                      ? l10n.eliminationNoRecord
                      : l10n.eliminationRecord(best),
                  key: const Key('elimination_best'),
                  style: gameFont(size: 22, color: AppColors.ink),
                ),
              ),
              OptionSection(
                index: 1,
                title: l10n.eliminationRulesTitle,
                icon: GameIconKind.flag,
                color: AppColors.pink,
                child: Column(
                  children: [
                    Text(
                      l10n.eliminationRules(EliminationChallenge.rounds),
                      textAlign: TextAlign.center,
                      style: fredoka(size: 15, weight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    for (final (from, to) in steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.roundsRange(from, to),
                                style: fredoka(
                                  size: 15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              l10n.goalMinimum(challenge.requiredPoints(from)),
                              style: gameFont(
                                size: 17,
                                color: AppColors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              OptionSection(
                index: 2,
                title: l10n.difficulty,
                icon: GameIconKind.flame,
                color: AppColors.orange,
                child: PillSelector<Difficulty>(
                  options: Difficulty.values,
                  isSelected: (d) => d == _difficulty,
                  label: (d) => d.label(l10n),
                  onTap: (d) => setState(() => _difficulty = d),
                ),
              ),
              OptionSection(
                index: 3,
                title: l10n.withFriends,
                icon: GameIconKind.group,
                color: AppColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.withFriendsHelp,
                      textAlign: TextAlign.center,
                      style: fredoka(size: 14, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('invite_friends'),
                      label: l10n.inviteFriends,
                      gameIcon: GameIconKind.group,
                      color: AppColors.cyan,
                      height: 54,
                      fontSize: 18,
                      onPressed: _invite,
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('join_friend'),
                      label: l10n.joinWithCode,
                      gameIcon: GameIconKind.key,
                      color: AppColors.white,
                      height: 50,
                      fontSize: 17,
                      onPressed: _joinFriend,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
