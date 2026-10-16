import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';

/// Boîte de réglage façon jeu : panneau à bordure colorée en relief, reflet
/// brillant en haut, et ruban titre centré à cheval sur le bord (pans repliés
/// de chaque côté, icône animée + titre). Les options sont centrées dessous.
class OptionSection extends StatelessWidget {
  const OptionSection({
    super.key,
    required this.index,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  /// Position dans la liste, pour l'apparition décalée.
  final int index;
  final String title;
  final GameIconKind icon;

  /// Couleur de la bordure et du ruban.
  final Color color;
  final Widget child;

  /// Hauteur du ruban qui dépasse au-dessus de la boîte.
  static const _bannerOverlap = 16.0;

  @override
  Widget build(BuildContext context) {
    final depth = AppColors.depthOf(color);
    // Texte foncé sur les couleurs claires (jaune, bleu…) pour rester lisible.
    final light = color.computeLuminance() > 0.3;
    final ink = light ? AppColors.ink : AppColors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BounceIn(
        delay: Duration(milliseconds: 60 * index),
        from: 0.85,
        slideY: 0.3,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Panneau : relief coloré dessous, fond légèrement teinté vers le
            // bas, liseré blanc intérieur.
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: _bannerOverlap),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: color,
                boxShadow: [
                  BoxShadow(color: depth, offset: const Offset(0, 6)),
                  const BoxShadow(
                    color: Color(0x33140744),
                    offset: Offset(0, 10),
                    blurRadius: 12,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 26, 12, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white,
                      Color.lerp(AppColors.white, color, 0.10)!,
                    ],
                  ),
                ),
                child: Center(child: child),
              ),
            ),
            // Reflet brillant le long du bord haut.
            Positioned(
              top: _bannerOverlap + 5,
              left: 14,
              right: 14,
              child: IgnorePointer(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0),
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Ribbon(
              color: color,
              depth: depth,
              ink: ink,
              light: light,
              icon: icon,
              title: title,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ruban titre avec ses pans repliés derrière, comme une bannière de jeu.
class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.color,
    required this.depth,
    required this.ink,
    required this.light,
    required this.icon,
    required this.title,
  });

  final Color color;
  final Color depth;
  final Color ink;
  final bool light;
  final GameIconKind icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    Widget tail(bool left) => CustomPaint(
      size: const Size(22, 24),
      painter: _TailPainter(depth, left: left),
    );

    // Les pans sont dessinés avant le ruban : ils passent derrière.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(left: -12, top: 8, child: tail(true)),
        Positioned(right: -12, top: 8, child: tail(false)),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 16, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.white, width: 2.5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(color, AppColors.white, 0.35)!, color],
            ),
            boxShadow: [BoxShadow(color: depth, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(icon, size: 21, color: ink),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: fredoka(
                  size: 15,
                  weight: FontWeight.w700,
                  color: ink,
                  shadows: light ? null : textShadow,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pan de ruban en queue d'aronde, plus sombre, qui passe derrière le ruban.
class _TailPainter extends CustomPainter {
  _TailPainter(this.color, {required this.left});

  final Color color;
  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = left
        ? (Path()
            ..moveTo(w, 0)
            ..lineTo(0, 0)
            ..lineTo(w * 0.35, h / 2)
            ..lineTo(0, h)
            ..lineTo(w, h)
            ..close())
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(w, 0)
            ..lineTo(w * 0.65, h / 2)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.left != left;
}
