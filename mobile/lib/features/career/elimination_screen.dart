import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_dialog.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/challenge.dart';
import '../game/data/models.dart';
import '../game/widgets/option_section.dart';
import '../game/widgets/pill_selector.dart';
import '../../animations/transitions/pop_route.dart';
import '../game/widgets/labels.dart';
import '../iq/iq_setup_screen.dart';
import '../online/data/room_models.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_header.dart';
import '../shop/shop_screen.dart';

/// Éliminatoires multijoueur : amis, duel, ou bots — jamais seul.
class EliminationScreen extends StatefulWidget {
  const EliminationScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<EliminationScreen> createState() => _EliminationScreenState();
}

class _EliminationScreenState extends State<EliminationScreen> {
  Difficulty _difficulty = Difficulty.normal;
  int _rounds = EliminationChallenge.defaultRounds;
  int _duration = EliminationChallenge.defaultDuration;
  bool _strictSpelling = false;
  int _maxPlayers = 8;

  /// Éliminatoires de Géographie & Nature ou de QI.
  RoomGame _game = RoomGame.letters;
  bool _iqSpeedBonus = true;
  bool _iqPenalty = false;

  bool get _iq => _game == RoomGame.iq;

  /// 0 = pas de dotation ; sinon pièces placées par le créateur.
  int _prize = 0;
  late final TextEditingController _prizeField;

  List<int> get _durationOptions => _iq
      ? IqSetupScreen.durationOptions
      : [
        for (final d in SoloGameSettings.durationOptions)
          if (!_strictSpelling || d >= Category.strictSpellingMinDuration) d,
      ];

  @override
  void initState() {
    super.initState();
    _prizeField = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = GameFeedbackScope.of(context).settings;
      if (!settings.eliminationRulesSeen) _showRules(automatic: true);
    });
  }

  Future<void> _showRules({bool automatic = false}) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;
    final body = automatic
        ? '${l10n.eliminationRulesIntro}\n\n${l10n.eliminationRules(_rounds)}'
        : l10n.eliminationRules(_rounds);
    await showGameInfo(
      context,
      icon: GameIconKind.flag,
      title: l10n.eliminationRulesTitle,
      message: body,
      okLabel: l10n.gotIt,
      accent: AppColors.pink,
    );
    settings.markEliminationRulesSeen();
  }

  @override
  void dispose() {
    _prizeField.dispose();
    super.dispose();
  }

  void _setGame(RoomGame game) {
    setState(() {
      _game = game;
      // Temps par énigme en QI : 15 à 60 s.
      if (!_durationOptions.contains(_duration)) {
        _duration = EliminationChallenge.defaultDuration;
      }
    });
  }

  void _setStrictSpelling(bool value) {
    setState(() {
      _strictSpelling = value;
      if (value && _duration < Category.strictSpellingMinDuration) {
        _duration = Category.strictSpellingMinDuration;
      }
    });
  }

  void _setPrize(int value) {
    final clamped = value.clamp(0, RoomKind.maxStake);
    setState(() => _prize = clamped);
    final text = clamped == 0 ? '' : '$clamped';
    if (_prizeField.text != text) {
      _prizeField.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onPrizeTyped(String raw) {
    if (raw.trim().isEmpty) {
      setState(() => _prize = 0);
      return;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    setState(() => _prize = parsed.clamp(0, RoomKind.maxStake));
  }

  Future<bool> _readyOnline() async {
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

  RoomSettings _settings() => RoomSettings(
        language: Localizations.localeOf(context).languageCode,
        difficulty: _difficulty,
        rounds: _rounds,
        roundDuration: _duration,
        strictSpelling: _strictSpelling && !_iq,
        maxPlayers: _maxPlayers,
        format: RoomFormat.elimination,
        game: _game,
        iqSpeedBonus: _iqSpeedBonus,
        iqPenalty: _iqPenalty,
        kind: _prize > 0 ? RoomKind.prize : RoomKind.classic,
        stake: _prize,
      );

  Future<bool> _ensurePrizeFunds() async {
    if (_prize <= 0) return true;
    final online = OnlineScope.of(context);
    if ((online.wallet?.coins ?? 0) >= _prize) return true;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.errorNotEnoughCoins),
        action: SnackBarAction(
          label: l10n.shopTitle,
          onPressed: () => Navigator.of(context).push(
            PopRoute(builder: (_) => const ShopScreen()),
          ),
        ),
      ),
    );
    return false;
  }

  Future<void> _openRoom() async {
    await Navigator.of(context)
        .push(PopRoute(builder: (_) => const RoomScreen()));
  }

  Future<void> _inviteFriends() async {
    if (!await _readyOnline() || !mounted) return;
    if (!await _ensurePrizeFunds() || !mounted) return;
    OnlineScope.of(context).createRoom(_settings());
    await _openRoom();
  }

  Future<void> _playWithBots() async {
    if (!await _readyOnline() || !mounted) return;
    if (!await _ensurePrizeFunds() || !mounted) return;
    final bots = _maxPlayers == 2 ? 1 : 3;
    OnlineScope.of(context).createRoom(
      _settings(),
      bots: bots,
      botLevel: _difficulty,
    );
    await _openRoom();
  }

  Future<void> _joinFriend() async {
    if (!await _readyOnline() || !mounted) return;
    final code = await askRoomCode(context);
    if (code == null || !mounted) return;
    OnlineScope.of(context).joinRoom(code);
    await _openRoom();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: GameBackground(
        theme: _iq ? BackgroundTheme.iq : BackgroundTheme.letters,
        child: SafeArea(
          child: FloatingBarsLayout(
            header: OnlineHeader(
              title: l10n.modeElimination,
              onBack: () => Navigator.of(context).pop(),
              helpTitle: l10n.eliminationRulesTitle,
              helpLabel: l10n.rulesButton,
              help: l10n.eliminationRules(_rounds),
              helpIcon: GameIconKind.flag,
            ),
            children: [
              OptionSection(
                index: 0,
                title: l10n.gamesTitle,
                icon: GameIconKind.trophy,
                color: AppColors.purpleLight,
                child: PillSelector<RoomGame>(
                  options: RoomGame.values,
                  isSelected: (g) => g == _game,
                  label: (g) => g == RoomGame.iq
                      ? l10n.gameIqTitle
                      : l10n.gameLettersTitle,
                  icon: (g) =>
                      g == RoomGame.iq ? GameIconKind.hint : GameIconKind.country,
                  onTap: _setGame,
                ),
              ),
              OptionSection(
                index: 0,
                title: l10n.roomType,
                icon: GameIconKind.duel,
                color: AppColors.cyan,
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
                title: l10n.rounds,
                icon: GameIconKind.layers,
                color: AppColors.cyan,
                child: PillSelector<int>(
                  options: SoloGameSettings.roundOptions,
                  isSelected: (r) => r == _rounds,
                  label: (r) => '$r',
                  onTap: (r) => setState(() => _rounds = r),
                ),
              ),
              OptionSection(
                index: 2,
                title: l10n.roundDuration,
                icon: GameIconKind.timer,
                color: AppColors.orange,
                child: PillSelector<int>(
                  options: _durationOptions,
                  isSelected: (d) => d == _duration,
                  label: (d) => durationLabel(l10n, d),
                  onTap: (d) => setState(() => _duration = d),
                ),
              ),
              OptionSection(
                index: 3,
                title: l10n.difficulty,
                icon: GameIconKind.flame,
                color: AppColors.orange,
                help: l10n.eliminationBotDifficultyHelp,
                child: Column(
                  children: [
                    PillSelector<Difficulty>(
                      options: Difficulty.values,
                      isSelected: (d) => d == _difficulty,
                      label: (d) => d.label(l10n),
                      onTap: (d) => setState(() => _difficulty = d),
                    ),
                    // Pas d'orthographe en QI.
                    if (!_iq) ...[
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
                  ],
                ),
              ),
              if (_iq)
                OptionSection(
                  index: 3,
                  title: l10n.iqScoring,
                  icon: GameIconKind.trophy,
                  color: AppColors.pink,
                  child: Column(
                    children: [
                      for (final (label, value, onChanged, key) in [
                        (
                          l10n.iqSpeedBonus,
                          _iqSpeedBonus,
                          (bool v) => setState(() => _iqSpeedBonus = v),
                          'elim_iq_speed_bonus',
                        ),
                        (
                          l10n.iqPenalty,
                          _iqPenalty,
                          (bool v) => setState(() => _iqPenalty = v),
                          'elim_iq_penalty',
                        ),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: fredoka(size: 15, color: AppColors.ink),
                                ),
                              ),
                              GameToggle(
                                key: Key(key),
                                value: value,
                                onChanged: onChanged,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              OptionSection(
                index: 4,
                title: l10n.winnerPrize,
                icon: GameIconKind.coin,
                color: AppColors.yellow,
                help: l10n.winnerPrizeHelp,
                child: Column(
                  children: [
                    PillSelector<int>(
                      options: const [0, ...RoomKind.stakeOptions],
                      isSelected: (s) => s == _prize,
                      label: (s) =>
                          s == 0 ? l10n.noPrize : l10n.stakeShort(s),
                      onTap: _setPrize,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('prize_field'),
                      controller: _prizeField,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      style: fredoka(
                        size: 18,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.prizeCustomHint,
                        hintStyle: fredoka(
                          size: 15,
                          color: AppColors.inkSoft,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: GameIcon(GameIconKind.coin, size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 24,
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.inkSoft,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: AppColors.inkSoft.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.yellow,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: _onPrizeTyped,
                    ),
                  ],
                ),
              ),
              OptionSection(
                index: 5,
                title: l10n.withFriends,
                icon: GameIconKind.group,
                color: AppColors.cyan,
                help: l10n.withFriendsHelp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CandyButton(
                      key: const Key('invite_friends'),
                      label: l10n.inviteFriends,
                      gameIcon: GameIconKind.group,
                      color: AppColors.cyan,
                      onPressed: _inviteFriends,
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('play_with_bots'),
                      label: _maxPlayers == 2
                          ? l10n.playVsBot
                          : l10n.playVsBots,
                      gameIcon: GameIconKind.bot,
                      color: AppColors.green,
                      onPressed: _playWithBots,
                    ),
                    const SizedBox(height: 10),
                    CandyButton(
                      key: const Key('join_friend'),
                      label: l10n.joinWithCode,
                      gameIcon: GameIconKind.key,
                      color: AppColors.white,
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
