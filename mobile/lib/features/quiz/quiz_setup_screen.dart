import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/duration_picker.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../online/data/room_models.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/widgets/online_header.dart';
import 'quiz_hub_screen.dart';
import 'quiz_models.dart';
import 'quiz_solo_screen.dart';

enum QuizSetupMode { room, bots, solo }

/// Réglages Chrono / Mot & Sens : solo local, salon ou bots.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.mode,
    required this.game,
    required this.title,
    required this.soloTitle,
    required this.theme,
    required this.accent,
    required this.questions,
  });

  final QuizSetupMode mode;
  final RoomGame game;
  final String title;
  final String soloTitle;
  final BackgroundTheme theme;
  final Color accent;
  final List<QuizQuestion> questions;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  int _rounds = 5;
  int _seconds = 0;
  bool _public = true;
  int _maxPlayers = 8;
  RoomFormat _format = RoomFormat.rounds;
  int _bots = 2;
  Difficulty _botLevel = Difficulty.normal;

  Future<void> _start() async {
    final navigator = Navigator.of(context);
    if (widget.mode == QuizSetupMode.solo) {
      navigator.pushReplacement(
        PopRoute(
          builder: (_) => QuizSoloScreen(
            title: widget.soloTitle,
            theme: widget.theme,
            accent: widget.accent,
            questions: widget.questions,
            game: widget.game.name,
            rounds: _rounds,
            secondsPerQuestion: _seconds,
          ),
        ),
      );
      return;
    }
    final bots = widget.mode == QuizSetupMode.bots;
    OnlineScope.of(context).createRoom(
      RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _botLevel,
        rounds: _rounds,
        roundDuration: _seconds,
        maxPlayers: bots ? _bots + 1 : _maxPlayers,
        public: !bots && _public,
        format: _format,
        game: widget.game,
      ),
      bots: bots ? _bots : 0,
      botLevel: _botLevel,
    );
    navigator.pushReplacement(PopRoute(builder: (_) => const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bots = widget.mode == QuizSetupMode.bots;
    final room = widget.mode == QuizSetupMode.room;
    return Scaffold(
      body: GameBackground(
        theme: widget.theme,
        palette: BackgroundPalette.history,
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: widget.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            footer: CandyButton(
              key: const Key('quiz_setup_start'),
              label: l10n.play.toUpperCase(),
              icon: Icons.play_arrow_rounded,
              color: widget.accent,
              textColor: AppColors.white,
              height: 48,
              fontSize: 17,
              onPressed: _start,
            ),
            children: [
              OptionSection(
                index: 1,
                title: l10n.quizQuestions,
                icon: GameIconKind.layers,
                color: AppColors.ochre,
                child: PillSelector<int>(
                  options: QuizHubScreen.roundOptions,
                  isSelected: (r) => r == _rounds,
                  label: (r) => '$r',
                  onTap: (r) => setState(() => _rounds = r),
                ),
              ),
              const SizedBox(height: 18),
              OptionSection(
                index: 2,
                title: l10n.quizTimePerQuestion,
                icon: GameIconKind.timer,
                color: AppColors.clay,
                child: DurationPicker(
                  value: _seconds,
                  options: QuizHubScreen.durationOptions,
                  onChanged: (d) => setState(() => _seconds = d),
                ),
              ),
              if (room) ...[
                const SizedBox(height: 18),
                OptionSection(
                  index: 3,
                  title: l10n.roomFormat,
                  icon: GameIconKind.layers,
                  color: AppColors.sage,
                  child: PillSelector<RoomFormat>(
                    options: const [RoomFormat.rounds, RoomFormat.relay],
                    isSelected: (f) => f == _format,
                    label: (f) => f == RoomFormat.relay
                        ? l10n.formatRelay
                        : l10n.formatRounds,
                    onTap: (f) => setState(() => _format = f),
                  ),
                ),
                const SizedBox(height: 18),
                OptionSection(
                  index: 4,
                  title: l10n.visibilityPublic,
                  icon: GameIconKind.public,
                  color: AppColors.dustyRose,
                  child: PillSelector<bool>(
                    options: const [true, false],
                    isSelected: (p) => p == _public,
                    label: (p) =>
                        p ? l10n.visibilityPublic : l10n.visibilityPrivate,
                    onTap: (p) => setState(() => _public = p),
                  ),
                ),
                const SizedBox(height: 18),
                OptionSection(
                  index: 5,
                  title: l10n.roomType,
                  icon: GameIconKind.group,
                  color: AppColors.sandDeep,
                  child: PillSelector<int>(
                    options: const [2, 4, 8],
                    isSelected: (n) => n == _maxPlayers,
                    label: (n) => '$n',
                    onTap: (n) => setState(() => _maxPlayers = n),
                  ),
                ),
              ],
              if (bots) ...[
                const SizedBox(height: 18),
                OptionSection(
                  index: 3,
                  title: l10n.opponents,
                  icon: GameIconKind.bot,
                  color: AppColors.sage,
                  child: PillSelector<int>(
                    options: const [1, 2, 3],
                    isSelected: (n) => n == _bots,
                    label: (n) => '$n',
                    onTap: (n) => setState(() => _bots = n),
                  ),
                ),
                const SizedBox(height: 18),
                OptionSection(
                  index: 4,
                  title: l10n.botLevel,
                  icon: GameIconKind.flame,
                  color: AppColors.ochre,
                  child: PillSelector<Difficulty>(
                    options: Difficulty.values,
                    isSelected: (d) => d == _botLevel,
                    label: (d) => d.label(l10n),
                    onTap: (d) => setState(() => _botLevel = d),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
