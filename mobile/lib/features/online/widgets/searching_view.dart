import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/candy_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/game_icon.dart';

/// Pulsation façon radar pendant que le serveur trouve ou crée une salle.
class SearchingView extends StatefulWidget {
  const SearchingView({super.key, required this.onCancel, this.label});

  final VoidCallback onCancel;
  final String? label;

  @override
  State<SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends State<SearchingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (GameFeedbackScope.of(context).ambientMotion && !_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          SizedBox.square(
            dimension: 220,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _RadarPainter(_pulse.value),
                child: const Center(
                  child: GameIcon(GameIconKind.search, size: 72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.label ?? l10n.searchingPlayers,
            textAlign: TextAlign.center,
            style: fredoka(
              size: 22,
              weight: FontWeight.w700,
              color: AppColors.white,
              shadows: textShadow,
            ),
          ),
          const Spacer(),
          CandyButton(
            label: l10n.cancel,
            color: AppColors.white,
            onPressed: widget.onCancel,
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    canvas.drawCircle(
      center,
      60,
      Paint()..color = AppColors.white.withValues(alpha: 0.25),
    );
    for (final lag in [0.0, 0.5]) {
      final p = (t + lag) % 1.0;
      canvas.drawCircle(
        center,
        60 + p * (maxRadius - 60),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppColors.white.withValues(alpha: (1 - p) * 0.6),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 60),
      t * 2 * pi,
      pi / 2,
      true,
      Paint()..color = AppColors.yellow.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.t != t;
}
