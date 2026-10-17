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
const worldColors = [
  AppColors.green,
  AppColors.cyan,
  AppColors.pink,
  AppColors.orange,
];

/// Carte des niveaux : 4 mondes de 15 niveaux. Chaque niveau réussi (au moins
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = GameFeedbackScope.of(context).settings;
      if (!settings.careerRulesSeen) _showRules(context, automatic: true);
    });
  }

  void _showRules(BuildContext context, {bool automatic = false}) {
    if (!automatic) GameFeedbackScope.of(context).play(Sfx.tap);
    final settings = GameFeedbackScope.of(context).settings;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CareerRulesSheet(),
    ).whenComplete(settings.markCareerRulesSeen);
  }

  Future<void> _open(BuildContext context, CareerLevel level) async {
    GameFeedbackScope.of(context).play(Sfx.tap);
    final played =
        (GameFeedbackScope.of(context).settings.careerStars[level.number] ??
            0) >
        0;
    final play = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LevelSheet(level: level, replay: played),
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
        avoidLetters: settings.careerLettersOf(level.number),
        bannedAnswers: settings.careerBannedAnswers(level.world),
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
    final worlds = [
      l10n.worldBeginner,
      l10n.worldConfirmed,
      l10n.worldExpert,
      l10n.worldMaster,
    ];
    const worldIcons = [
      GameIconKind.smile,
      GameIconKind.flame,
      GameIconKind.trophy,
      GameIconKind.crown,
    ];

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RulesButton(onPressed: () => _showRules(context)),
                          const SizedBox(width: 8),
                          _StarCount(
                            total: total,
                            max: careerLevels.length * 3,
                          ),
                        ],
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
                            icon: worldIcons[w],
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

/// Bouton « Règles », écrit en toutes lettres.
class _RulesButton extends StatelessWidget {
  const _RulesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('career_rules'),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.purpleDeep.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white, width: 2),
        ),
        child: Text(
          AppLocalizations.of(context).eliminationRulesTitle,
          style: gameFont(size: 14, color: AppColors.white),
        ),
      ),
    );
  }
}

/// Règles de la carrière : mondes, catégories qui s'ajoutent, étoiles.
class _CareerRulesSheet extends StatelessWidget {
  const _CareerRulesSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.yellow, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.depthOf(AppColors.yellow),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.eliminationRulesTitle.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: gameFont(size: 26, color: AppColors.ink),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.careerRulesIntro,
                    textAlign: TextAlign.center,
                    style: fredoka(size: 15, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.careerRulesFromConfirmed,
                    textAlign: TextAlign.center,
                    style: fredoka(size: 15, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  _RuleBlock(
                    title: l10n.worldBeginner,
                    color: worldColors[0],
                    text: l10n.careerRulesBeginner,
                  ),
                  _RuleBlock(
                    title: l10n.worldConfirmed,
                    color: worldColors[1],
                    text: l10n.careerRulesConfirmed,
                  ),
                  _RuleBlock(
                    title: l10n.worldExpert,
                    color: worldColors[2],
                    text: l10n.careerRulesExpert,
                  ),
                  _RuleBlock(
                    title: l10n.worldMaster,
                    color: worldColors[3],
                    text: l10n.careerRulesMaster,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.careerRulesReuse,
                    textAlign: TextAlign.center,
                    style: fredoka(size: 14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.careerRulesStars,
                    textAlign: TextAlign.center,
                    style: fredoka(size: 14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  CandyButton(
                    label: l10n.gotIt,
                    icon: Icons.check_rounded,
                    color: AppColors.green,
                    textColor: AppColors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.title,
    required this.color,
    required this.text,
  });

  final String title;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.depthOf(color),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: gameFont(size: 16, color: AppColors.ink)),
                Text(text, style: fredoka(size: 14, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Détails d'un niveau avant de le lancer.
class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.level, required this.replay});

  final CareerLevel level;

  /// Le niveau a déjà au moins une étoile : on propose une revanche.
  final bool replay;

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
              label: replay ? l10n.playAgain : l10n.play,
              icon: replay ? Icons.replay_rounded : Icons.play_arrow_rounded,
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
