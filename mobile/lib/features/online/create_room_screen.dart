import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/pill_selector.dart';
import '../game/widgets/option_section.dart';
import 'data/room_models.dart';
import '../../animations/transitions/pop_route.dart';
import '../shop/shop_screen.dart';
import 'online_controller.dart';
import 'room_screen.dart';
import 'widgets/online_counter.dart';
import 'widgets/online_header.dart';

/// Options de la salle ; ouvre le lobby par-dessus pour que Retour revienne ici.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  RoomKind _kind = RoomKind.classic;
  RoomFormat _format = RoomFormat.rounds;
  RoomTheme _theme = RoomTheme.none;
  int _stake = 10;
  int _maxPlayers = 8;
  bool _public = true;
  int _rounds = 5;
  int _duration = 30;
  bool _strictSpelling = false;
  Difficulty _difficulty = Difficulty.normal;
  final Set<Category> _categories = {...Category.classic};

  /// Beaucoup de catégories : les manches doivent durer plus de 30 s.
  bool get _manyCategories => _categories.length >= Category.many;

  int get _minDuration {
    final many = _manyCategories ? Category.manyMinDuration : 0;
    final strict = _strictSpelling ? Category.strictSpellingMinDuration : 0;
    return many > strict ? many : strict;
  }

  List<int> get _durationOptions => [
    for (final d in SoloGameSettings.durationOptions)
      if (d >= _minDuration) d,
  ];

  void _setStrictSpelling(bool value) {
    setState(() {
      _strictSpelling = value;
      if (_duration < _minDuration) _duration = _minDuration;
    });
  }

  void _toggleCategory(Category category) {
    setState(() {
      if (!_categories.contains(category)) {
        _categories.add(category);
        if (_duration < _minDuration) _duration = _minDuration;
      } else if (_categories.length > 1) {
        _categories.remove(category);
      }
    });
  }

  void _create() {
    final online = OnlineScope.of(context);
    if (_kind == RoomKind.bet && (online.wallet?.coins ?? 0) < _stake) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorNotEnoughCoins),
          action: SnackBarAction(
            label: l10n.shopTitle,
            onPressed: () =>
                Navigator.of(context)
                    .push(PopRoute(builder: (_) => const ShopScreen())),
          ),
        ),
      );
      return;
    }
    online.createRoom(
      RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _difficulty,
        categories: [
          for (final c in Category.values)
            if (_categories.contains(c)) c,
        ],
        rounds: _rounds,
        roundDuration: _duration,
        strictSpelling: _strictSpelling,
        maxPlayers: _maxPlayers,
        public: _public,
        kind: _kind,
        stake: _kind == RoomKind.bet ? _stake : 0,
        format: _format,
        theme: _theme,
      ),
    );
    // Garde cet écran sous le lobby : Retour = création → salons → accueil.
    Navigator.of(context).push(PopRoute(builder: (_) => const RoomScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: l10n.createRoomTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
            footer: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: CandyButton(
                label: l10n.create,
                icon: Icons.check_rounded,
                color: AppColors.green,
                textColor: AppColors.white,
                onPressed: _create,
              ),
            ),
            children: [
              OptionSection(
                index: 0,
                title: l10n.roomKind,
                icon: GameIconKind.bet,
                color: AppColors.yellow,
                help: l10n.betRules,
                child: PillSelector<RoomKind>(
                  options: const [RoomKind.classic, RoomKind.bet],
                  isSelected: (k) => k == _kind,
                  label: (k) => k == RoomKind.bet
                      ? l10n.roomKindBet
                      : l10n.roomKindClassic,
                  icon: (k) =>
                      k == RoomKind.bet ? GameIconKind.bet : GameIconKind.smile,
                  onTap: (k) => setState(() => _kind = k),
                ),
              ),
              if (_kind == RoomKind.bet)
                OptionSection(
                  index: 0,
                  title: l10n.stake,
                  icon: GameIconKind.coin,
                  color: AppColors.orange,
                  help: l10n.betRules,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PillSelector<int>(
                        options: RoomKind.stakeOptions,
                        isSelected: (s) => s == _stake,
                        label: (s) => '$s',
                        icon: (_) => GameIconKind.coin,
                        onTap: (s) => setState(() => _stake = s),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.yourCoins(OnlineScope.of(context).wallet?.coins ?? 0)} · ${l10n.betRules}',
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 13,
                          weight: FontWeight.w500,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              OptionSection(
                index: 1,
                title: l10n.roomType,
                icon: GameIconKind.duel,
                color: AppColors.green,
                help: l10n.roomTypeHelp,
                child: PillSelector<int>(
                  options: const [2, 8],
                  isSelected: (n) => n == _maxPlayers,
                  label: (n) => n == 2 ? l10n.roomTypeDuel : l10n.roomTypeGroup,
                  icon: (n) => n == 2 ? GameIconKind.duel : GameIconKind.group,
                  onTap: (n) => setState(() => _maxPlayers = n),
                ),
              ),
              OptionSection(
                index: 1,
                title: l10n.roomFormat,
                icon: GameIconKind.layers,
                color: AppColors.purpleLight,
                // Éliminatoires = mode à part (accueil), pas une option ici.
                help: '${l10n.formatRoundsHelpLong}\n\n${l10n.formatRelayHelp}',
                child: Column(
                  children: [
                    PillSelector<RoomFormat>(
                      options: const [RoomFormat.rounds, RoomFormat.relay],
                      isSelected: (f) => f == _format,
                      label: (f) => switch (f) {
                        RoomFormat.rounds => l10n.formatRounds,
                        RoomFormat.relay => l10n.formatRelay,
                        RoomFormat.elimination => l10n.formatElimination,
                      },
                      onTap: (f) => setState(() => _format = f),
                    ),
                    if (_format == RoomFormat.relay) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.formatRelayHelp,
                        textAlign: TextAlign.center,
                        style: fredoka(size: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              OptionSection(
                index: 1,
                title: l10n.roomTheme,
                icon: GameIconKind.flag,
                color: AppColors.orange,
                help: l10n.roomThemeHelp,
                child: PillSelector<RoomTheme>(
                  options: RoomTheme.values,
                  isSelected: (t) => t == _theme,
                  label: (t) => switch (t) {
                    RoomTheme.none => l10n.themeNone,
                    RoomTheme.geography => l10n.themeGeography,
                    RoomTheme.names => l10n.themeNames,
                    RoomTheme.nature => l10n.themeNature,
                  },
                  onTap: (t) => setState(() => _theme = t),
                ),
              ),
              OptionSection(
                index: 2,
                title: l10n.visibility,
                icon: GameIconKind.public,
                color: AppColors.cyan,
                help: l10n.visibilityHelp,
                child: Column(
                  children: [
                    PillSelector<bool>(
                      options: const [true, false],
                      isSelected: (p) => p == _public,
                      label: (p) =>
                          p ? l10n.visibilityPublic : l10n.visibilityPrivate,
                      icon: (p) => p ? GameIconKind.public : GameIconKind.private,
                      onTap: (p) => setState(() => _public = p),
                    ),
                    if (_public) const PublicAudience(),
                  ],
                ),
              ),
              OptionSection(
                index: 3,
                title: l10n.rounds,
                icon: GameIconKind.layers,
                color: AppColors.yellow,
                help: l10n.formatRoundsHelpLong,
                child: PillSelector<int>(
                  options: SoloGameSettings.roundOptions,
                  isSelected: (r) => r == _rounds,
                  label: (r) => '$r',
                  onTap: (r) => setState(() => _rounds = r),
                ),
              ),
              OptionSection(
                index: 4,
                title: l10n.roundDuration,
                icon: GameIconKind.timer,
                color: AppColors.cyan,
                help: l10n.durationHelp,
                child: Column(
                  children: [
                    PillSelector<int>(
                      options: _durationOptions,
                      isSelected: (d) => d == _duration,
                      label: (d) => durationLabel(l10n, d),
                      onTap: (d) => setState(() => _duration = d),
                    ),
                    if (_manyCategories) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.manyCategoriesHint(Category.many),
                        key: const Key('many_categories_hint'),
                        textAlign: TextAlign.center,
                        style: fredoka(size: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              OptionSection(
                index: 5,
                title: l10n.categories,
                icon: GameIconKind.categories,
                color: AppColors.pink,
                help: l10n.manyCategoriesHint(Category.many),
                child: PillSelector<Category>(
                  options: Category.values,
                  isSelected: _categories.contains,
                  label: (c) => c.label(l10n),
                  icon: (c) => c.icon,
                  iconColor: (c) => c.color,
                  onTap: _toggleCategory,
                ),
              ),
              OptionSection(
                index: 6,
                title: l10n.difficulty,
                icon: GameIconKind.flame,
                color: AppColors.orange,
                help: l10n.difficultyHelp,
                child: Column(
                  children: [
                    PillSelector<Difficulty>(
                      options: Difficulty.values,
                      isSelected: (d) => d == _difficulty,
                      label: (d) => d.label(l10n),
                      onTap: (d) => setState(() => _difficulty = d),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.strictSpelling,
                            style: fredoka(
                              size: 15,
                              weight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        InfoTip(
                          title: l10n.strictSpelling,
                          message: l10n.strictSpellingHelp,
                          okLabel: l10n.gotIt,
                          icon: GameIconKind.flag,
                          accent: AppColors.purpleLight,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        GameToggle(
                          value: _strictSpelling,
                          onChanged: _setStrictSpelling,
                        ),
                      ],
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
