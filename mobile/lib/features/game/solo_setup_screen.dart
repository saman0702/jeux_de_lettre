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
import '../online/data/room_models.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import 'data/models.dart';
import 'data/solo_backend.dart';
import 'offline/offline_dictionary.dart';
import 'offline/offline_engine.dart';
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
  int _bots = 0;
  Difficulty _botLevel = Difficulty.normal;
  bool _loading = false;

  List<Category> get _selectedCategories => [
    for (final c in Category.values)
      if (_categories.contains(c)) c,
  ];

  /// Against bots the game runs online, like a room with computer players.
  Future<void> _startAgainstBots() async {
    final l10n = AppLocalizations.of(context);
    final online = OnlineScope.of(context);
    if (!online.isOnline) {
      online.client.connect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(l10n, 'network_error'))),
      );
      return;
    }
    if (!await ensureNickname(context) || !mounted) return;
    online.createRoom(
      RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _difficulty,
        categories: _selectedCategories,
        rounds: _rounds,
        roundDuration: _duration,
        maxPlayers: _bots + 1,
      ),
      bots: _bots,
      botLevel: _botLevel,
    );
    Navigator.of(context)
        .pushReplacement(PopRoute(builder: (_) => const RoomScreen()));
  }

  Future<void> _start() async {
    if (_bots > 0) return _startAgainstBots();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    final settings = SoloGameSettings(
      language: Localizations.localeOf(context).languageCode,
      difficulty: _difficulty,
      categories: _selectedCategories,
      rounds: _rounds,
      roundDuration: _duration,
      nickname: l10n.defaultNickname,
    );

    SoloBackend backend = _api;
    SoloGame game;
    try {
      game = await _api.createGame(settings);
    } on ApiException catch (e) {
      if (e.code != 'network_error') {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessage(l10n, e.code))),
        );
        if (mounted) setState(() => _loading = false);
        return;
      }
      // No server: the whole game runs on the device.
      backend = OfflineSoloBackend(await OfflineDictionary.load());
      game = await backend.createGame(settings);
      messenger.showSnackBar(SnackBar(content: Text(l10n.offlineModeNotice)));
    }

    navigator.pushReplacement(
      PopRoute(
        builder: (_) => SoloGameScreen(
          api: backend,
          game: game,
          apiClient: widget.apiClient,
        ),
      ),
    );
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
                    section(
                      4,
                      l10n.opponents,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PillSelector<int>(
                            options: const [0, 1, 2, 3],
                            isSelected: (n) => n == _bots,
                            label: (n) => n == 0 ? l10n.opponentsNone : '🤖 $n',
                            onTap: (n) => setState(() => _bots = n),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: _bots == 0
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.botLevel,
                                          style: fredoka(
                                            size: 15,
                                            weight: FontWeight.w600,
                                            color: AppColors.inkSoft,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        PillSelector<Difficulty>(
                                          options: Difficulty.values,
                                          isSelected: (d) => d == _botLevel,
                                          label: (d) => d.label(l10n),
                                          onTap: (d) =>
                                              setState(() => _botLevel = d),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
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
