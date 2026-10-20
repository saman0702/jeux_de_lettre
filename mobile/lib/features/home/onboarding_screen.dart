import 'package:flutter/material.dart';

import 'country_picker.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/game_toggle.dart';
import '../../core/widgets/brand_mark.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/pill_selector.dart';
import 'home_screen.dart';

/// Premier lancement : langue, genre, sons / musique.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameFeedbackScope.of(context).setMusic(MusicMood.menu);
    });
  }

  void _finish() {
    final settings = GameFeedbackScope.of(context).settings;
    settings.languageCode ??= 'fr';
    settings.completeOnboarding();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GameFeedbackScope.of(context).settings;

    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandMark(size: 0.72)),
                    const SizedBox(height: 18),
                    Text(
                      l10n.onboardingTitle,
                      textAlign: TextAlign.center,
                      style: fredoka(
                        size: 28,
                        weight: FontWeight.w800,
                        color: AppColors.white,
                        shadows: textShadow,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.onboardingSubtitle,
                      textAlign: TextAlign.center,
                      style: fredoka(
                        size: 15,
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _Card(
                              child: _LanguageBlock(
                                value: settings.languageCode,
                                onChanged: (code) =>
                                    settings.languageCode = code,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Card(
                              child: _GenderBlock(
                                value: settings.gender,
                                onChanged: (g) => settings.gender = g,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Pays d'origine : drapeau vu par les autres joueurs.
                            _Card(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.settingsCountry,
                                      style: fredoka(size: 16, weight: FontWeight.w700),
                                    ),
                                  ),
                                  CountryButton(
                                    value: settings.country,
                                    onChanged: (c) => settings.country = c,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Card(
                              child: Column(
                                children: [
                                  _ToggleRow(
                                    icon: GameIconKind.sound,
                                    color: AppColors.cyan,
                                    label: l10n.settingsSound,
                                    value: settings.sound,
                                    onChanged: (v) => settings.sound = v,
                                  ),
                                  const SizedBox(height: 10),
                                  _ToggleRow(
                                    icon: GameIconKind.music,
                                    color: AppColors.pink,
                                    label: l10n.settingsMusic,
                                    value: settings.music,
                                    onChanged: (v) => settings.music = v,
                                  ),
                                  const SizedBox(height: 8),
                                  _VolumeRow(
                                    enabled: settings.music,
                                    value: settings.musicVolume,
                                    onChanged: (v) => settings.musicVolume = v,
                                  ),
                                  const SizedBox(height: 10),
                                  _ToggleRow(
                                    icon: GameIconKind.vibration,
                                    color: AppColors.orange,
                                    label: l10n.settingsVibration,
                                    value: settings.vibration,
                                    onChanged: (v) => settings.vibration = v,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CandyButton(
                      key: const Key('onboarding_continue'),
                      label: l10n.onboardingContinue,
                      gameIcon: GameIconKind.bolt,
                      color: AppColors.yellow,
                      onPressed: _finish,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellow, width: 3),
      ),
      child: child,
    );
  }
}

class _LanguageBlock extends StatelessWidget {
  const _LanguageBlock({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsLanguage,
          style: fredoka(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        PillSelector<String?>(
          options: const [null, 'fr', 'en'],
          isSelected: (code) => code == value,
          label: (code) => switch (code) {
            'fr' => 'FR',
            'en' => 'EN',
            _ => l10n.languageAuto,
          },
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _GenderBlock extends StatelessWidget {
  const _GenderBlock({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsGender,
          style: fredoka(size: 16, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        PillSelector<String?>(
          options: const ['male', 'female', 'other'],
          isSelected: (code) => code == value,
          label: (code) => switch (code) {
            'male' => l10n.genderMale,
            'female' => l10n.genderFemale,
            _ => l10n.genderOther,
          },
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final GameIconKind icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GameIconBadge(icon, color: color, size: 40, dimmed: !value),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: fredoka(size: 16, weight: FontWeight.w700),
          ),
        ),
        GameToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsMusicVolume,
            style: fredoka(size: 14, weight: FontWeight.w600),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.pink,
              inactiveTrackColor: const Color(0xFFDCD3F2),
              thumbColor: AppColors.pink,
              overlayColor: AppColors.pink.withValues(alpha: 0.15),
            ),
            child: Slider(
              key: const Key('onboarding_music_volume'),
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
