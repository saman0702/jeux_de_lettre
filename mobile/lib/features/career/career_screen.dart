import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/outlined_text.dart';
import '../../core/widgets/scroll_under_bars.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/challenge.dart';
import '../game/solo_launcher.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/option_section.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import 'career_levels.dart';

/// Couleur de chaque monde de la carrière.
const worldColors = [AppColors.green, AppColors.cyan, AppColors.pink];

/// Carte des niveaux : 3 mondes de 10 niveaux. Chaque niveau réussi (au moins
/// une étoile) ouvre le suivant.
class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  /// Partie en préparation : un voile de chargement montre que ça démarre.
  bool _launching = false;

  Future<void> _open(BuildContext context, CareerLevel level) async {
    GameFeedbackScope.of(context).play(Sfx.tap);
    final play = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LevelSheet(level: level),
    );
    if (play != true || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;
    setState(() => _launching = true);
    await launchSoloGame(
      context,
      apiClient: widget.apiClient,
      settings: level.settings(
        Localizations.localeOf(context).languageCode,
        settings.nickname ?? l10n.defaultNickname,
        OnlineScope.of(context).clientId,
      ),
      challenge: level,
      // La carte reste dessous : on y revient après la partie.
      replace: false,
    );
    if (mounted) setState(() => _launching = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;
    final worlds = [l10n.worldBeginner, l10n.worldConfirmed, l10n.worldExpert];

    return Scaffold(
      body: GameBackground(
        child: Stack(
          children: [
            SafeArea(
              child: ListenableBuilder(
                listenable: settings,
                builder: (context, _) {
                  final stars = settings.careerStars;
                  final total = stars.values.fold(0, (a, b) => a + b);
                  return ScrollUnderBars(
                    header: OnlineHeader(
                      title: l10n.careerTitle,
                      onBack: () => Navigator.of(context).pop(),
                      trailing: _StarCount(
                        total: total,
                        max: careerLevels.length * 3,
                      ),
                    ),
                    builder: (context, padding) => ListView(
                      padding: padding.copyWith(
                        left: 16,
                        right: 16,
                        top: padding.top + 6,
                      ),
                      children: [
                        for (var w = 0; w < worlds.length; w++)
                          OptionSection(
                            index: w,
                            title: worlds[w],
                            icon: [
                              GameIconKind.smile,
                              GameIconKind.flame,
                              GameIconKind.trophy,
                            ][w],
                            color: worldColors[w],
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final level in careerLevels.where(
                                  (l) => l.world == w,
                                ))
                                  _LevelTile(
                                    level: level,
                                    stars: stars[level.number] ?? 0,
                                    unlocked: settings.careerUnlocked(
                                      level.number,
                                    ),
                                    onTap: () => _open(context, level),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_launching) const Positioned.fill(child: _LaunchingVeil()),
          ],
        ),
      ),
    );
  }
}

/// Voile pendant la préparation de la partie.
class _LaunchingVeil extends StatelessWidget {
  const _LaunchingVeil();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      key: const Key('career_launching'),
      color: AppColors.ink.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 56,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: AppColors.yellow,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedText(
              l10n.preparingGame,
              style: gameFont(size: 22, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarCount extends StatelessWidget {
  const _StarCount({required this.total, required this.max});

  final int total;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.purpleDeep.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.yellow, size: 22),
          const SizedBox(width: 2),
          Text(
            '$total / $max',
            key: const Key('career_stars'),
            style: gameFont(size: 15, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}

/// Case d'un niveau : numéro, étoiles gagnées, cadenas tant qu'il est fermé.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  final CareerLevel level;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? worldColors[level.world] : AppColors.grey;
    // Le prochain niveau à jouer est mis en avant.
    final current = unlocked && stars == 0;
    return GestureDetector(
      key: Key('career_level_${level.number}'),
      onTap: unlocked ? onTap : null,
      child: BounceIn(
        from: 0.6,
        delay: Duration(milliseconds: 20 * (level.number % 10)),
        child: SizedBox(
          width: 58,
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, AppColors.white, 0.3)!, color],
                  ),
                  border: Border.all(
                    color: current ? AppColors.yellow : AppColors.white,
                    width: current ? 3.5 : 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.depthOf(color),
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: unlocked
                    ? OutlinedText(
                        '${level.number}',
                        strokeWidth: 3,
                        style: gameFont(size: 22, color: AppColors.white),
                      )
                    : const Icon(
                        Icons.lock_rounded,
                        color: AppColors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: i < stars
                          ? AppColors.yellow
                          : const Color(0xFFDCD3F2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Détails d'un niveau avant de le lancer.
class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.level});

  final CareerLevel level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = worldColors[level.world];
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: fredoka(size: 14, weight: FontWeight.w600)),
    );

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(color),
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.levelTitle(level.number).toUpperCase(),
              textAlign: TextAlign.center,
              style: gameFont(size: 26, color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                chip(level.difficulty.label(l10n)),
                chip(l10n.roundsCount(level.rounds)),
                chip(l10n.secondsShort(level.roundDuration)),
                for (final c in level.categories)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cloud,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GameIcon(c.icon, size: 20, color: c.color),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.levelGoal(level.target),
              textAlign: TextAlign.center,
              style: gameFont(size: 20, color: AppColors.purple),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.careerStarsInfo(
                level.target,
                level.twoStars,
                level.threeStars,
              ),
              textAlign: TextAlign.center,
              style: fredoka(size: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            CandyButton(
              key: const Key('play_level'),
              label: l10n.play,
              icon: Icons.play_arrow_rounded,
              color: AppColors.green,
              textColor: AppColors.white,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
