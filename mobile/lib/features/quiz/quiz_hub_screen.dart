import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/duration_picker.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../online/widgets/online_header.dart';
import 'quiz_models.dart';
import 'quiz_solo_screen.dart';

/// Hub d’un module quiz : réglage manches + temps, puis lancement solo.
class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({
    super.key,
    required this.title,
    required this.soloTitle,
    required this.theme,
    required this.accent,
    required this.questions,
    required this.soloKey,
    required this.game,
    this.apiClient,
  });

  final String title;
  final String soloTitle;
  final BackgroundTheme theme;
  final Color accent;
  final List<QuizQuestion> questions;
  final Key soloKey;

  /// `chrono` ou `mots`.
  final String game;
  final ApiClient? apiClient;

  static const roundOptions = [3, 5, 10, 15];
  static const durationOptions = [10, 15, 20, 30, 45];

  @override
  State<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState extends State<QuizHubScreen> {
  int _rounds = 5;
  /// Illimité par défaut (comme le solo lettres / QI).
  int _seconds = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: GameBackground(
        theme: widget.theme,
        palette: BackgroundPalette.history,
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: widget.title,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: CandyButton(
                  key: widget.soloKey,
                  label: l10n.iqSolo,
                  icon: Icons.play_arrow_rounded,
                  color: widget.accent,
                  textColor: AppColors.white,
                  height: 48,
                  fontSize: 17,
                  onPressed: () {
                    Navigator.of(context).push(
                      PopRoute(
                        builder: (_) => QuizSoloScreen(
                          title: widget.soloTitle,
                          theme: widget.theme,
                          accent: widget.accent,
                          questions: widget.questions,
                          game: widget.game,
                          rounds: _rounds,
                          secondsPerQuestion: _seconds,
                          apiClient: widget.apiClient,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
