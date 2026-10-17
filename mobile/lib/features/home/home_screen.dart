import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/letter_tile.dart';
import '../../l10n/app_localizations.dart';
import '../career/career_screen.dart';
import '../career/elimination_screen.dart';
import '../game/solo_setup_screen.dart';
import '../game/widgets/labels.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_counter.dart';
import '../avatar/avatar_screen.dart';
import '../online/widgets/player_avatar.dart';
import '../wallet/coin_counter.dart';
import '../wallet/level_badge.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameFeedbackScope.of(context).setMusic(MusicMood.menu);
    });
  }

  void _openSolo() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => SoloSetupScreen(apiClient: _api)));
  }

  void _openCareer() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => CareerScreen(apiClient: _api)));
  }

  void _openElimination() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => EliminationScreen(apiClient: _api)));
  }

  /// Les modes en ligne demandent une connexion et un pseudo.
  Future<bool> _readyForOnline() async {
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

  Future<void> _quickMatch() async {
    if (!await _readyForOnline() || !mounted) return;
    OnlineScope.of(context)
        .quickMatch(Localizations.localeOf(context).languageCode);
    Navigator.of(context).push(PopRoute(builder: (_) => const RoomScreen()));
  }

  Future<void> _openRooms() async {
    if (!await _readyForOnline() || !mounted) return;
    Navigator.of(context).push(PopRoute(builder: (_) => const RoomsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      // Les boîtes de dialogue (pseudo, code) gèrent le clavier ; le menu ne
      // doit pas rétrécir.
      resizeToAvoidBottomInset: false,
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Rétrécit sur les petits écrans plutôt que de déborder.
                    // Prend toute la place libre : réglages et avatar restent
                    // à droite.
                    const Flexible(
                      fit: FlexFit.tight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            OnlineCounter(),
                            SizedBox(width: 8),
                            CoinCounter(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MyAvatarButton(
                      onTap: () => Navigator.of(context).push(
                        PopRoute(builder: (_) => AvatarScreen(apiClient: _api)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    RoundIconButton(
                      key: const Key('settings_button'),
                      icon: Icons.settings_rounded,
                      tooltip: l10n.settingsTitle,
                      color: AppColors.yellow,
                      iconColor: AppColors.ink,
                      spinOnTap: true,
                      onPressed: () => showSettingsSheet(context),
                    ),
                  ],
                ),
                const Spacer(),
                const _Logo(),
                const SizedBox(height: 20),
                BounceIn(
                  delay: const Duration(milliseconds: 900),
                  child: Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: fredoka(
                      size: 17,
                      color: AppColors.white,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Carrière en grand, puis les autres modes deux par deux.
                BounceIn(
                  delay: const Duration(milliseconds: 700),
                  slideY: 0.6,
                  child: CandyButton(
                    key: const Key('mode_career'),
                    label: l10n.modeCareer,
                    gameIcon: GameIconKind.trophy,
                    color: AppColors.yellow,
                    onPressed: _openCareer,
                  ),
                ),
                const SizedBox(height: 12),
                for (final (row, buttons) in [
                  (
                    0,
                    [
                      (
                        l10n.modeFreeSolo,
                        GameIconKind.person,
                        AppColors.orange,
                        _openSolo,
                        'mode_solo',
                      ),
                      (
                        l10n.modeElimination,
                        GameIconKind.flag,
                        AppColors.pink,
                        _openElimination,
                        'mode_elimination',
                      ),
                    ],
                  ),
                  (
                    1,
                    [
                      (
                        l10n.modeQuickMatch,
                        GameIconKind.bolt,
                        AppColors.cyan,
                        _quickMatch,
                        'mode_quick',
                      ),
                      (
                        l10n.modeRooms,
                        GameIconKind.group,
                        AppColors.green,
                        _openRooms,
                        'mode_rooms',
                      ),
                    ],
                  ),
                ]) ...[
                  Row(
                    children: [
                      for (final (i, (label, icon, color, onPressed, key))
                          in buttons.indexed) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: BounceIn(
                            delay: Duration(
                              milliseconds: 820 + row * 120 + i * 60,
                            ),
                            slideY: 0.6,
                            child: CandyButton(
                              key: Key(key),
                              label: label,
                              gameIcon: icon,
                              color: color,
                              textColor: color == AppColors.green
                                  ? AppColors.white
                                  : AppColors.ink,
                              height: 58,
                              fontSize: 17,
                              onPressed: onPressed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mon avatar en haut de l'accueil ; ouvre le choix d'avatar.
class _MyAvatarButton extends StatelessWidget {
  const _MyAvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = OnlineScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.avatarTitle,
      child: GestureDetector(
        key: const Key('avatar_button'),
        onTap: onTap,
        child: ListenableBuilder(
          listenable: online,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              PlayerAvatar(
                nickname: '',
                seed: online.clientId,
                size: 46,
                preset: online.avatarPreset,
                photoUrl: online.avatarUrl,
                frame: online.look.frame,
                hair: online.look.hair,
                hat: online.look.hat,
              ),
              Positioned(
                right: -6,
                bottom: -4,
                child: LevelBadge(level: online.level),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logo en tuiles de lettres, animé en boucle : une vague fait sauter les
/// tuiles l'une après l'autre (avec écrasement à l'atterrissage), elles se
/// balancent doucement, et une tuile différente fait un tour sur elle-même à
/// chaque boucle.
class _Logo extends StatefulWidget {
  const _Logo();

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  static const _colors = [
    AppColors.yellow,
    AppColors.pink,
    AppColors.cyan,
    AppColors.green,
    AppColors.orange,
  ];

  /// Durée d'une boucle d'animation, en secondes.
  static const _loop = 5.0;
  static const _tiles = 12;

  /// Laisse le temps aux tuiles d'arriver (BounceIn) avant de bouger.
  static const _start = 1.6;

  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMilliseconds / 1000,
  );
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = GameFeedbackScope.of(context).ambientMotion;
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  /// Saut de la tuile [index] : hauteur (0 à 1) et écrasement.
  static (double, double) _jump(int index, double local) {
    // La vague traverse le logo en ~1 s ; chaque saut dure 0,45 s.
    final p = (local - index * 0.075) / 0.45;
    if (p <= 0 || p >= 1.25) return (0, 1);
    if (p < 1) return (sin(p * pi), 1);
    // Petit écrasement juste après l'atterrissage.
    return (0, 1 - 0.12 * sin((p - 1) / 0.25 * pi));
  }

  Widget _tile(String char, int index, double t) {
    final active = t > _start;
    final elapsed = active ? t - _start : 0.0;
    final loop = (elapsed / _loop).floor();
    final local = elapsed % _loop;

    final (lift, squash) = active ? _jump(index, local) : (0.0, 1.0);
    final sway = active ? sin(elapsed * 1.6 + index * 0.7) * 0.04 : 0.0;
    // Tour complet, sur une tuile différente à chaque boucle.
    final flipping = active && (loop * 5) % _tiles == index;
    final flip = flipping
        ? Curves.easeInOutBack.transform(((local - 2.4) / 0.7).clamp(0.0, 1.0))
        : 0.0;
    final base = (index.isEven ? 1 : -1) * 0.06;

    return Transform.translate(
      offset: Offset(0, -lift * 14),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()..scaleByDouble(2 - squash, squash, 1, 1),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateZ(base + sway + lift * 0.08 * (index.isEven ? -1 : 1))
            ..rotateY(flip * 2 * pi),
          child: LetterTile(
            letter: char,
            size: 44,
            color: _colors[index % _colors.length],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String word, int offset) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (j, char) in word.split('').indexed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: BounceIn(
              delay: Duration(milliseconds: 60 * (offset + j)),
              slideY: -1.5,
              child: ValueListenableBuilder<double>(
                valueListenable: _time,
                builder: (context, t, _) => _tile(char, offset + j, t),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label: 'Letter Race',
      child: Column(
        children: [
          row('LETTER', 0),
          const SizedBox(height: 8),
          row('RACE', 6),
        ],
      ),
    );
  }
}
