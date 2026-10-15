import 'package:flutter/material.dart';

import '../../animations/bounce_in.dart';
import '../../animations/transitions/pop_route.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/letter_tile.dart';
import '../../l10n/app_localizations.dart';
import '../game/solo_setup_screen.dart';
import '../game/widgets/labels.dart';
import '../online/nickname_dialog.dart';
import '../online/online_controller.dart';
import '../online/room_screen.dart';
import '../online/rooms_screen.dart';
import '../online/widgets/online_counter.dart';
import 'settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool? _serverOnline;

  @override
  void initState() {
    super.initState();
    _checkServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameFeedbackScope.of(context).musicWanted = true;
    });
  }

  Future<void> _checkServer() async {
    final online = await _api.checkHealth();
    if (mounted) setState(() => _serverOnline = online);
  }

  void _openSolo() {
    Navigator.of(context)
        .push(PopRoute(builder: (_) => SoloSetupScreen(apiClient: _api)));
  }

  /// Online modes need a connection and a nickname.
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
      // Dialogs (nickname, code) handle the keyboard; the menu must not shrink.
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
                    const OnlineCounter(),
                    const Spacer(),
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
                for (final (i, (label, icon, color, onPressed, badge)) in [
                  (
                    l10n.modeSolo,
                    Icons.person_rounded,
                    AppColors.yellow,
                    _openSolo,
                    null,
                  ),
                  (
                    l10n.modeQuickMatch,
                    Icons.bolt_rounded,
                    AppColors.orange,
                    _quickMatch,
                    null,
                  ),
                  (
                    l10n.modeRooms,
                    Icons.groups_rounded,
                    AppColors.cyan,
                    _openRooms,
                    null,
                  ),
                ].indexed) ...[
                  BounceIn(
                    delay: Duration(milliseconds: 700 + i * 120),
                    slideY: 0.6,
                    child: CandyButton(
                      label: label,
                      icon: icon,
                      color: color,
                      badge: badge,
                      onPressed: onPressed,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Spacer(),
                _ServerStatus(online: _serverOnline, onRetry: _checkServer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  static const _colors = [
    AppColors.yellow,
    AppColors.pink,
    AppColors.cyan,
    AppColors.green,
    AppColors.orange,
  ];

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
              child: Transform.rotate(
                angle: ((offset + j).isEven ? 1 : -1) * 0.06,
                child: LetterTile(
                  letter: char,
                  size: 44,
                  color: _colors[(offset + j) % _colors.length],
                ),
              ),
            ),
          ),
      ],
    );

    return Semantics(
      label: 'Letter Battle',
      child: Column(
        children: [
          row('LETTER', 0),
          const SizedBox(height: 8),
          row('BATTLE', 6),
        ],
      ),
    );
  }
}

class _ServerStatus extends StatelessWidget {
  const _ServerStatus({required this.online, required this.onRetry});

  final bool? online;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (color, label) = switch (online) {
      null => (AppColors.grey, l10n.serverChecking),
      true => (AppColors.green, l10n.serverOnline),
      false => (AppColors.red, l10n.serverOffline),
    };

    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.white.withValues(alpha: 0.15),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: Icon(Icons.circle, size: 12, color: color),
        label: Text(label, style: fredoka(size: 14, color: AppColors.white)),
      ),
    );
  }
}
