// Icône Mind Race : un cerveau qui fonce (traits de vitesse), les initiales
// E B S J A qui flottent autour, style « bonbon » du jeu.
//
// Pour régénérer l'icône :
//   flutter test tool/render_app_icon_test.dart --update-goldens
//   ../backend/.venv/bin/python tool/export_app_icon.py
// (dans tool/, ce fichier ne tourne pas avec les tests habituels).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _purple = Color(0xFF6C3CE1);
const _yellow = Color(0xFFFFC93C);
const _cyan = Color(0xFF3CC8FF);
const _green = Color(0xFF2ECC71);
const _red = Color(0xFFFF5A5F);
const _orange = Color(0xFFFF8A3D);

/// Initiales flottantes : lettre, position, taille, inclinaison, couleur.
const _initials = [
  ('E', Offset(175, 205), 128.0, -0.32, _green),
  ('B', Offset(165, 800), 120.0, 0.22, _purple),
  ('S', Offset(430, 885), 118.0, -0.18, _orange),
  ('J', Offset(655, 135), 116.0, 0.26, _red),
  ('A', Offset(905, 745), 122.0, 0.30, _yellow),
];

class BrainIconPainter extends CustomPainter {
  BrainIconPainter({this.rounded = true});

  /// Coins arrondis (Android) ; carré plein pour iOS, qui arrondit lui-même.
  final bool rounded;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 1024);
    final background = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(1024, 1024),
        [const Color(0xFF8E52F5), const Color(0xFF4A23C2)],
      );
    if (rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          const Radius.circular(230),
        ),
        background,
      );
    } else {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), background);
    }
    // Halo doux derrière le cerveau.
    canvas.drawCircle(
      const Offset(590, 500),
      380,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(590, 500), 380, [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ]),
    );

    // Traits de vitesse, derrière le cerveau.
    void streak(double y, double x0, double x1, Color color, double width) {
      canvas.drawLine(
        Offset(x0, y),
        Offset(x1, y),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    streak(390, 120, 330, _yellow, 34);
    streak(505, 70, 300, Colors.white, 38);
    streak(620, 140, 330, _cyan, 34);

    _brain(canvas);

    // Étincelles.
    void sparkle(Offset o, double k, Color color) {
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final a = -pi / 2 + i * pi / 4;
        final rad = i.isEven ? k : k * 0.32;
        final pt = o + Offset(cos(a) * rad, sin(a) * rad);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path..close(), Paint()..color = color);
    }

    sparkle(const Offset(880, 200), 58, _yellow);
    sparkle(const Offset(935, 345), 30, Colors.white);
    sparkle(const Offset(720, 905), 32, _cyan);

    for (final (letter, at, size, turn, color) in _initials) {
      _letter(canvas, letter, at, size, turn, color);
    }
  }

  void _brain(Canvas canvas) {
    const c = Offset(600, 500);
    const r = 255.0;
    const lobes = [
      (-0.62, -0.10, 0.42), (-0.32, -0.52, 0.44), (0.12, -0.62, 0.44),
      (0.52, -0.40, 0.42), (0.70, 0.02, 0.40), (0.50, 0.40, 0.40),
      (0.08, 0.50, 0.42), (-0.36, 0.42, 0.40), (-0.66, 0.24, 0.34),
      (0.0, 0.0, 0.62),
    ];
    var brain = Path();
    for (final (dx, dy, k) in lobes) {
      brain = Path.combine(
        PathOperation.union,
        brain,
        Path()
          ..addOval(
            Rect.fromCircle(center: c + Offset(dx * r, dy * r), radius: k * r),
          ),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.10);
    canvas.translate(-c.dx, -c.dy);
    // Relief dessous, contour blanc, rose en dégradé.
    canvas.drawPath(
      brain.shift(const Offset(0, 26)),
      Paint()..color = const Color(0xFFB0145F),
    );
    canvas.drawPath(
      brain,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      brain,
      Paint()
        ..shader = ui.Gradient.linear(
          c + const Offset(-200, -250),
          c + const Offset(150, 280),
          [const Color(0xFFFFA8CF), const Color(0xFFFF5FA2)],
        ),
    );
    // Circonvolutions.
    canvas.save();
    canvas.clipPath(brain);
    final fold = Paint()
      ..color = const Color(0xFFD93A82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    Offset p(double x, double y) => c + Offset(x * r, y * r);
    canvas.drawPath(
      Path()
        ..moveTo(p(0.05, -0.95).dx, p(0.05, -0.95).dy)
        ..cubicTo(p(-0.15, -0.55).dx, p(-0.15, -0.55).dy, p(0.25, -0.25).dx,
            p(0.25, -0.25).dy, p(0.05, 0.05).dx, p(0.05, 0.05).dy)
        ..cubicTo(p(-0.12, 0.30).dx, p(-0.12, 0.30).dy, p(0.15, 0.45).dx,
            p(0.15, 0.45).dy, p(0.05, 0.70).dx, p(0.05, 0.70).dy),
      fold,
    );
    void curl(double x0, double y0, double x1, double y1, double x2, double y2) {
      canvas.drawPath(
        Path()
          ..moveTo(p(x0, y0).dx, p(x0, y0).dy)
          ..quadraticBezierTo(p(x1, y1).dx, p(x1, y1).dy, p(x2, y2).dx, p(x2, y2).dy),
        fold,
      );
    }

    curl(-0.75, -0.15, -0.50, -0.30, -0.30, -0.05);
    curl(-0.55, 0.30, -0.35, 0.10, -0.15, 0.30);
    curl(-0.45, -0.65, -0.25, -0.45, -0.38, -0.25);
    curl(0.35, -0.70, 0.30, -0.40, 0.55, -0.30);
    curl(0.40, -0.05, 0.65, -0.15, 0.80, 0.10);
    curl(0.30, 0.25, 0.50, 0.45, 0.35, 0.65);
    canvas.drawOval(
      Rect.fromCenter(center: p(-0.30, -0.55), width: 170, height: 70),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();
    canvas.restore();
  }

  /// Lettre épaisse colorée, cernée de blanc, avec une petite ombre.
  void _letter(Canvas canvas, String letter, Offset at, double size, double turn, Color color) {
    TextPainter painter(Paint paint) => TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(fontFamily: 'LilitaOne', fontSize: size, height: 1, foreground: paint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final shadow = painter(Paint()..color = const Color(0x55140744));
    final outline = painter(
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.16
        ..strokeJoin = StrokeJoin.round,
    );
    final fill = painter(Paint()..color = color);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(turn);
    final origin = Offset(-fill.width / 2, -fill.height / 2);
    shadow.paint(canvas, origin + const Offset(0, 9));
    outline.paint(canvas, origin);
    fill.paint(canvas, origin);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _font(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void main() {
  for (final (rounded, name) in [(true, 'mind_race_icon'), (false, 'mind_race_icon_ios')]) {
    testWidgets(name, (tester) async {
      await _font('LilitaOne', 'assets/fonts/LilitaOne.ttf');
      tester.view.physicalSize = const Size(1024, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const Key('icon'),
            child: CustomPaint(
              size: const Size(1024, 1024),
              painter: BrainIconPainter(rounded: rounded),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const Key('icon')),
        matchesGoldenFile('../assets/branding/$name.png'),
      );
    });
  }
}
