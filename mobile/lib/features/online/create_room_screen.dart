import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/floating_bars_layout.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/pill_selector.dart';
import '../game/widgets/option_section.dart';
import 'data/room_models.dart';
import 'online_controller.dart';
import 'widgets/online_header.dart';

/// Options de la salle ; renvoie `true` une fois la demande de création
/// envoyée.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  RoomKind _kind = RoomKind.classic;
  int _stake = 10;
  int _maxPlayers = 8;
  bool _public = true;
  int _rounds = 5;
  int _duration = 30;
  Difficulty _difficulty = Difficulty.normal;
  final Set<Category> _categories = {...Category.values};

  void _toggleCategory(Category category) {
    setState(() {
      if (!_categories.contains(category)) {
        _categories.add(category);
      } else if (_categories.length > 1) {
        _categories.remove(category);
      }
    });
  }

  void _create() {
    final online = OnlineScope.of(context);
    if (_kind == RoomKind.bet && (online.wallet?.coins ?? 0) < _stake) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorNotEnoughCoins),
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
        maxPlayers: _maxPlayers,
        public: _public,
        kind: _kind,
        stake: _kind == RoomKind.bet ? _stake : 0,
      ),
    );
    Navigator.of(context).pop(true);
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
                child: PillSelector<RoomKind>(
                  options: RoomKind.values,
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
                        style: fredoka(
                          size: 13,
                          weight: FontWeight.w500,
                          color: AppColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              OptionSection(
                index: 1,
                title: l10n.roomType,
                child: PillSelector<int>(
                  options: const [2, 8],
                  isSelected: (n) => n == _maxPlayers,
                  label: (n) => n == 2 ? l10n.roomTypeDuel : l10n.roomTypeGroup,
                  icon: (n) => n == 2 ? GameIconKind.duel : GameIconKind.group,
                  onTap: (n) => setState(() => _maxPlayers = n),
                ),
              ),
              OptionSection(
                index: 2,
                title: l10n.visibility,
                child: PillSelector<bool>(
                  options: const [true, false],
                  isSelected: (p) => p == _public,
                  label: (p) =>
                      p ? l10n.visibilityPublic : l10n.visibilityPrivate,
                  icon: (p) => p ? GameIconKind.public : GameIconKind.private,
                  onTap: (p) => setState(() => _public = p),
                ),
              ),
              OptionSection(
                index: 3,
                title: l10n.rounds,
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
                child: PillSelector<int>(
                  options: SoloGameSettings.durationOptions,
                  isSelected: (d) => d == _duration,
                  label: (d) => l10n.secondsShort(d),
                  onTap: (d) => setState(() => _duration = d),
                ),
              ),
              OptionSection(
                index: 5,
                title: l10n.categories,
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
                child: PillSelector<Difficulty>(
                  options: Difficulty.values,
                  isSelected: (d) => d == _difficulty,
                  label: (d) => d.label(l10n),
                  onTap: (d) => setState(() => _difficulty = d),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
