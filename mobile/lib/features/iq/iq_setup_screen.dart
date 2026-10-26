import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../online/data/room_models.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/widgets/online_header.dart';
import 'iq_models.dart';
import 'iq_solo_screen.dart';

enum IqSetupMode { room, bots, solo }

/// Réglages d'une partie de QI : nombre d'énigmes, temps, difficulté, points ;
/// pour un salon aussi la visibilité, la taille et le format ; contre les
/// bots leur nombre et leur niveau.
class IqSetupScreen extends StatefulWidget {
  const IqSetupScreen({super.key, required this.mode, this.apiClient});

  final IqSetupMode mode;
  final ApiClient? apiClient;

  static const durationOptions = [15, 30, 45, 60];

  @override
  State<IqSetupScreen> createState() => _IqSetupScreenState();
}

class _IqSetupScreenState extends State<IqSetupScreen> {
  int _rounds = 10;
  int _duration = 30;
  Difficulty _difficulty = Difficulty.normal;
  bool _speedBonus = true;
  bool _penalty = false;
  bool _public = true;
  int _maxPlayers = 8;
  RoomFormat _format = RoomFormat.rounds;
  int _bots = 2;
  Difficulty _botLevel = Difficulty.normal;

  void _start() {
    final navigator = Navigator.of(context);
    final scoring = IqScoring(speedBonus: _speedBonus, penalty: _penalty);
    if (widget.mode == IqSetupMode.solo) {
      navigator.pushReplacement(
        PopRoute(
          builder: (_) => IqSoloScreen(
            rounds: _rounds,
            duration: _duration,
            difficulty: _difficulty,
            scoring: scoring,
            apiClient: widget.apiClient,
          ),
        ),
      );
      return;
    }
    final bots = widget.mode == IqSetupMode.bots;
    OnlineScope.of(context).createRoom(
      RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _difficulty,
        rounds: _rounds,
        roundDuration: _duration,
        maxPlayers: bots ? _bots + 1 : _maxPlayers,
        public: !bots && _public,
        format: _format,
        game: RoomGame.iq,
        iqSpeedBonus: _speedBonus,
        iqPenalty: _penalty,
      ),
      bots: bots ? _bots : 0,
      botLevel: _botLevel,
    );
    navigator.pushReplacement(PopRoute(builder: (_) => const RoomScreen()));
  }

  Widget _toggle(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
    Key key,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: fredoka(size: 15, color: AppColors.ink)),
        ),
        GameToggle(key: key, value: value, onChanged: onChanged),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (widget.mode) {
      IqSetupMode.room => l10n.iqRoomTitle,
      IqSetupMode.bots => l10n.iqBotsTitle,
      IqSetupMode.solo => l10n.iqSoloTitle,
    };
    var index = 0;
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: title,
              onBack: () => Navigator.of(context).pop(),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: CandyButton(
                key: const Key('iq_start'),
                label: widget.mode == IqSetupMode.room
                    ? l10n.create
                    : l10n.play,
                icon: Icons.check_rounded,
                color: AppColors.green,
                textColor: AppColors.white,
                onPressed: _start,
              ),
            ),
            children: [
              if (widget.mode == IqSetupMode.bots) ...[
                OptionSection(
                  index: index++,
                  title: l10n.opponents,
                  icon: GameIconKind.bot,
                  color: AppColors.cyan,
                  child: PillSelector<int>(
                    options: const [1, 2, 3],
                    isSelected: (n) => n == _bots,
                    label: (n) => '$n',
                    icon: (_) => GameIconKind.bot,
                    onTap: (n) => setState(() => _bots = n),
                  ),
                ),
                OptionSection(
                  index: index++,
                  title: l10n.botLevel,
                  icon: GameIconKind.flame,
                  color: AppColors.orange,
                  child: PillSelector<Difficulty>(
                    options: Difficulty.values,
                    isSelected: (d) => d == _botLevel,
                    label: (d) => d.label(l10n),
                    onTap: (d) => setState(() => _botLevel = d),
                  ),
                ),
              ],
              if (widget.mode == IqSetupMode.room) ...[
                OptionSection(
                  index: index++,
                  title: l10n.roomType,
                  icon: GameIconKind.duel,
                  color: AppColors.green,
                  help: l10n.roomTypeHelp,
                  child: PillSelector<int>(
                    options: const [2, 8],
                    isSelected: (n) => n == _maxPlayers,
                    label: (n) =>
                        n == 2 ? l10n.roomTypeDuel : l10n.roomTypeGroup,
                    icon: (n) =>
                        n == 2 ? GameIconKind.duel : GameIconKind.group,
                    onTap: (n) => setState(() => _maxPlayers = n),
                  ),
                ),
                OptionSection(
                  index: index++,
                  title: l10n.visibility,
                  icon: GameIconKind.public,
                  color: AppColors.cyan,
                  help: l10n.visibilityHelp,
                  child: PillSelector<bool>(
                    options: const [true, false],
                    isSelected: (p) => p == _public,
                    label: (p) =>
                        p ? l10n.visibilityPublic : l10n.visibilityPrivate,
                    icon: (p) => p ? GameIconKind.public : GameIconKind.private,
                    onTap: (p) => setState(() => _public = p),
                  ),
                ),
              ],
              if (widget.mode != IqSetupMode.solo)
                OptionSection(
                  index: index++,
                  title: l10n.roomFormat,
                  icon: GameIconKind.layers,
                  color: AppColors.purpleLight,
                  help:
                      '${l10n.formatRoundsHelp}\n\n${l10n.formatEliminationHelp}',
                  child: PillSelector<RoomFormat>(
                    options: const [RoomFormat.rounds, RoomFormat.elimination],
                    isSelected: (f) => f == _format,
                    label: (f) => f == RoomFormat.elimination
                        ? l10n.formatElimination
                        : l10n.formatRounds,
                    onTap: (f) => setState(() => _format = f),
                  ),
                ),
              OptionSection(
                index: index++,
                title: l10n.iqQuestions,
                icon: GameIconKind.layers,
                color: AppColors.yellow,
                child: PillSelector<int>(
                  options: SoloGameSettings.roundOptions,
                  isSelected: (r) => r == _rounds,
                  label: (r) => '$r',
                  onTap: (r) => setState(() => _rounds = r),
                ),
              ),
              OptionSection(
                index: index++,
                title: l10n.iqTimePerQuestion,
                icon: GameIconKind.timer,
                color: AppColors.cyan,
                child: PillSelector<int>(
                  options: IqSetupScreen.durationOptions,
                  isSelected: (d) => d == _duration,
                  label: (d) => durationLabel(l10n, d),
                  onTap: (d) => setState(() => _duration = d),
                ),
              ),
              OptionSection(
                index: index++,
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
                index: index++,
                title: l10n.iqScoring,
                icon: GameIconKind.trophy,
                color: AppColors.pink,
                child: Column(
                  children: [
                    _toggle(
                      l10n.iqSpeedBonus,
                      _speedBonus,
                      (v) => setState(() => _speedBonus = v),
                      const Key('iq_speed_bonus'),
                    ),
                    _toggle(
                      l10n.iqPenalty,
                      _penalty,
                      (v) => setState(() => _penalty = v),
                      const Key('iq_penalty'),
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
