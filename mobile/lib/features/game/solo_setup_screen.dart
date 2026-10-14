import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../l10n/app_localizations.dart';
import 'data/models.dart';
import 'data/solo_game_api.dart';
import 'solo_game_screen.dart';
import 'widgets/labels.dart';
import 'widgets/pill_selector.dart';

class SoloSetupScreen extends StatefulWidget {
  const SoloSetupScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends State<SoloSetupScreen> {
  late final SoloGameApi _api = SoloGameApi(widget.apiClient);
  int _rounds = 5;
  int _duration = 30;
  Difficulty _difficulty = Difficulty.normal;
  final Set<Category> _categories = {...Category.values};
  bool _loading = false;

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    try {
      final game = await _api.createGame(
        SoloGameSettings(
          language: Localizations.localeOf(context).languageCode,
          difficulty: _difficulty,
          categories: [
            for (final c in Category.values)
              if (_categories.contains(c)) c,
          ],
          rounds: _rounds,
          roundDuration: _duration,
          nickname: l10n.defaultNickname,
        ),
      );
      navigator.pushReplacement(
        PopRoute(
          builder: (_) => SoloGameScreen(
            api: _api,
            game: game,
            apiClient: widget.apiClient,
          ),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(l10n, e.code))),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleCategory(Category category) {
    setState(() {
      if (!_categories.contains(category)) {
        _categories.add(category);
      } else if (_categories.length > 1) {
        _categories.remove(category);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).selectOneCategory),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget section(int index, String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BounceIn(
        delay: Duration(milliseconds: 80 * index),
        from: 0.8,
        slideY: 0.3,
        child: GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: fredoka(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.soloSetupTitle,
                      style: fredoka(
                        size: 26,
                        weight: FontWeight.w700,
                        color: AppColors.white,
                        shadows: textShadow,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    section(
                      0,
                      l10n.rounds,
                      PillSelector<int>(
                        options: SoloGameSettings.roundOptions,
                        isSelected: (r) => r == _rounds,
                        label: (r) => '$r',
                        onTap: (r) => setState(() => _rounds = r),
                      ),
                    ),
                    section(
                      1,
                      l10n.roundDuration,
                      PillSelector<int>(
                        options: SoloGameSettings.durationOptions,
                        isSelected: (d) => d == _duration,
                        label: (d) => l10n.secondsShort(d),
                        onTap: (d) => setState(() => _duration = d),
                      ),
                    ),
                    section(
                      2,
                      l10n.categories,
                      PillSelector<Category>(
                        options: Category.values,
                        isSelected: _categories.contains,
                        label: (c) => '${c.emoji} ${c.label(l10n)}',
                        onTap: _toggleCategory,
                      ),
                    ),
                    section(
                      3,
                      l10n.difficulty,
                      PillSelector<Difficulty>(
                        options: Difficulty.values,
                        isSelected: (d) => d == _difficulty,
                        label: (d) => d.label(l10n),
                        onTap: (d) => setState(() => _difficulty = d),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: CandyButton(
                  label: l10n.startGame,
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.green,
                  textColor: AppColors.white,
                  loading: _loading,
                  onPressed: _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
