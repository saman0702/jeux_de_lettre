import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/data/models.dart';
import '../game/widgets/labels.dart';
import '../game/widgets/pill_selector.dart';
import 'data/room_models.dart';
import 'online_controller.dart';
import 'widgets/online_header.dart';

/// Room options; pops `true` once the creation request is sent.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
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
    OnlineScope.of(context).createRoom(
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
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget section(int index, String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BounceIn(
        delay: Duration(milliseconds: 60 * index),
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
              OnlineHeader(
                title: l10n.createRoomTitle,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    section(
                      0,
                      l10n.roomType,
                      PillSelector<int>(
                        options: const [2, 8],
                        isSelected: (n) => n == _maxPlayers,
                        label: (n) =>
                            n == 2 ? l10n.roomTypeDuel : l10n.roomTypeGroup,
                        icon: (n) =>
                            n == 2 ? GameIconKind.duel : GameIconKind.group,
                        onTap: (n) => setState(() => _maxPlayers = n),
                      ),
                    ),
                    section(
                      1,
                      l10n.visibility,
                      PillSelector<bool>(
                        options: const [true, false],
                        isSelected: (p) => p == _public,
                        label: (p) =>
                            p ? l10n.visibilityPublic : l10n.visibilityPrivate,
                        icon: (p) =>
                            p ? GameIconKind.public : GameIconKind.private,
                        onTap: (p) => setState(() => _public = p),
                      ),
                    ),
                    section(
                      2,
                      l10n.rounds,
                      PillSelector<int>(
                        options: SoloGameSettings.roundOptions,
                        isSelected: (r) => r == _rounds,
                        label: (r) => '$r',
                        onTap: (r) => setState(() => _rounds = r),
                      ),
                    ),
                    section(
                      3,
                      l10n.roundDuration,
                      PillSelector<int>(
                        options: SoloGameSettings.durationOptions,
                        isSelected: (d) => d == _duration,
                        label: (d) => l10n.secondsShort(d),
                        onTap: (d) => setState(() => _duration = d),
                      ),
                    ),
                    section(
                      4,
                      l10n.categories,
                      PillSelector<Category>(
                        options: Category.values,
                        isSelected: _categories.contains,
                        label: (c) => c.label(l10n),
                        icon: (c) => c.icon,
                        iconColor: (c) => c.color,
                        onTap: _toggleCategory,
                      ),
                    ),
                    section(
                      5,
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
                  label: l10n.create,
                  icon: Icons.check_rounded,
                  color: AppColors.green,
                  textColor: AppColors.white,
                  onPressed: _create,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
