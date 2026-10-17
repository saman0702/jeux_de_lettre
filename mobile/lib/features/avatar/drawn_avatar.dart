import 'dart:math';

import 'package:flutter/material.dart';

enum _Hair {
  none,
  spiky,
  bob,
  cap,
  bun,
  bow,
  headphones,
  catEars,
  bunnyEars,
  curly,
}

enum _Eyes { dots, happy, wink, shiny }

enum _Mouth { smile, grin, tongue, oh }

class _Look {
  const _Look(
    this.background,
    this.skin,
    this.hairColor,
    this.hair,
    this.eyes,
    this.mouth,
  );

  final Color background;
  final Color skin;
  final Color hairColor;
  final _Hair hair;
  final _Eyes eyes;
  final _Mouth mouth;
}

/// Les personnages proposés ; l'indice est ce que le serveur enregistre.
const _looks = [
  _Look(
    Color(0xFFFFC93C),
    Color(0xFFF2B98C),
    Color(0xFF3B2A1A),
    _Hair.spiky,
    _Eyes.dots,
    _Mouth.grin,
  ),
  _Look(
    Color(0xFFFF6FA8),
    Color(0xFFFFD9B8),
    Color(0xFFB8432F),
    _Hair.bob,
    _Eyes.shiny,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFF3FD0E0),
    Color(0xFF8E5A3B),
    Color(0xFF1C1C2E),
    _Hair.curly,
    _Eyes.happy,
    _Mouth.grin,
  ),
  _Look(
    Color(0xFF6BE07A),
    Color(0xFFC98A5E),
    Color(0xFFE5484D),
    _Hair.cap,
    _Eyes.dots,
    _Mouth.tongue,
  ),
  _Look(
    Color(0xFFFF9A3C),
    Color(0xFF5E3A27),
    Color(0xFF1C1C2E),
    _Hair.bun,
    _Eyes.shiny,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFFB79CFF),
    Color(0xFFFFD9B8),
    Color(0xFFFFC93C),
    _Hair.bow,
    _Eyes.happy,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFF3FD0E0),
    Color(0xFFF2B98C),
    Color(0xFF6C4BD8),
    _Hair.headphones,
    _Eyes.wink,
    _Mouth.grin,
  ),
  _Look(
    Color(0xFFFFC93C),
    Color(0xFFFFE9D6),
    Color(0xFF7A5230),
    _Hair.catEars,
    _Eyes.shiny,
    _Mouth.oh,
  ),
  _Look(
    Color(0xFFFF6FA8),
    Color(0xFFC98A5E),
    Color(0xFFFFFFFF),
    _Hair.bunnyEars,
    _Eyes.dots,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFF6BE07A),
    Color(0xFF8E5A3B),
    Color(0xFF1C1C2E),
    _Hair.spiky,
    _Eyes.wink,
    _Mouth.tongue,
  ),
  _Look(
    Color(0xFFB79CFF),
    Color(0xFF5E3A27),
    Color(0xFFFF6FA8),
    _Hair.curly,
    _Eyes.shiny,
    _Mouth.grin,
  ),
  _Look(
    Color(0xFFFF9A3C),
    Color(0xFFFFD9B8),
    Color(0xFF3B2A1A),
    _Hair.none,
    _Eyes.happy,
    _Mouth.grin,
  ),
  _Look(
    Color(0xFF3FD0E0),
    Color(0xFFFFD9B8),
    Color(0xFF2F9E5B),
    _Hair.cap,
    _Eyes.shiny,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFFFFC93C),
    Color(0xFF8E5A3B),
    Color(0xFFE5484D),
    _Hair.bow,
    _Eyes.dots,
    _Mouth.oh,
  ),
  _Look(
    Color(0xFF6BE07A),
    Color(0xFFF2B98C),
    Color(0xFF1C1C2E),
    _Hair.headphones,
    _Eyes.happy,
    _Mouth.smile,
  ),
  _Look(
    Color(0xFFFF6FA8),
    Color(0xFF5E3A27),
    Color(0xFF3B2A1A),
    _Hair.catEars,
    _Eyes.wink,
    _Mouth.grin,
  ),
];

/// Nombre d'avatars dessinés au choix.
const drawnAvatarCount = 16;

/// Couleur de fond d'un avatar dessiné (pour les ombres et bordures).
Color drawnAvatarColor(int preset) => _looks[preset % _looks.length].background;

/// Un personnage dessiné, rond, dans le style cartoon du jeu.
/// [hairId] / [hatId] : équipements boutique (vides = style du preset).
class DrawnAvatar extends StatelessWidget {
  const DrawnAvatar({
    super.key,
    required this.preset,
    this.size = 52,
    this.hairId = '',
    this.hatId = '',
  });

  final int preset;
  final double size;
  final String hairId;
  final String hatId;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _AvatarPainter(
      _looks[preset % _looks.length],
      hairId: hairId,
      hatId: hatId,
    ),
  );
}

/// Calque chapeau seul (photo ou aperçu boutique).
class AvatarHatLayer extends StatelessWidget {
  const AvatarHatLayer({super.key, required this.hatId, this.size = 52});

  final String hatId;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (hatId.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.square(size),
      painter: _HatOnlyPainter(hatId),
    );
  }
}

class _HatOnlyPainter extends CustomPainter {
  _HatOnlyPainter(this.hatId);

  final String hatId;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width);
    _drawShopHat(canvas, hatId);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatOnlyPainter oldDelegate) => oldDelegate.hatId != hatId;
}

(_Hair, Color)? _shopHairOf(String id) => switch (id) {
  'hair_spiky' => (_Hair.spiky, const Color(0xFF1C1C2E)),
  'hair_bob' => (_Hair.bob, const Color(0xFFFF6FA8)),
  'hair_curly' => (_Hair.curly, const Color(0xFF3FD0E0)),
  'hair_bun' => (_Hair.bun, const Color(0xFFFFC93C)),
  _ => null,
};

bool _isAccessoryHair(_Hair hair) => switch (hair) {
  _Hair.cap ||
  _Hair.bow ||
  _Hair.headphones ||
  _Hair.catEars ||
  _Hair.bunnyEars => true,
  _ => false,
};

void _drawShopHat(Canvas canvas, String hatId) {
  switch (hatId) {
    case 'hat_crown':
      final gold = Paint()..color = const Color(0xFFFFC93C);
      final dark = Paint()..color = const Color(0xFFE09A1A);
      final jewel = Paint()..color = const Color(0xFFFF5FA2);
      final band = Path()
        ..moveTo(0.22, 0.28)
        ..lineTo(0.28, 0.12)
        ..lineTo(0.36, 0.24)
        ..lineTo(0.5, 0.08)
        ..lineTo(0.64, 0.24)
        ..lineTo(0.72, 0.12)
        ..lineTo(0.78, 0.28)
        ..close();
      canvas.drawPath(band, gold);
      canvas.drawRect(const Rect.fromLTWH(0.22, 0.26, 0.56, 0.08), dark);
      for (final x in [0.36, 0.5, 0.64]) {
        canvas.drawCircle(Offset(x, 0.28), 0.035, jewel);
      }
    case 'hat_cap':
      final red = Paint()..color = const Color(0xFFE5484D);
      final brim = Paint()..color = const Color(0xFFB83238);
      final cap = Path()
        ..moveTo(0.22, 0.38)
        ..quadraticBezierTo(0.22, 0.14, 0.5, 0.14)
        ..quadraticBezierTo(0.78, 0.14, 0.78, 0.38)
        ..close();
      canvas.drawPath(cap, red);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0.4, 0.34, 0.48, 0.08),
          const Radius.circular(0.04),
        ),
        brim,
      );
      canvas.drawCircle(
        const Offset(0.5, 0.16),
        0.03,
        Paint()..color = Colors.white,
      );
    case 'hat_wizard':
      final purple = Paint()..color = const Color(0xFF6C4BD8);
      final tip = Paint()..color = const Color(0xFFB79CFF);
      canvas.drawPath(
        Path()
          ..moveTo(0.2, 0.36)
          ..lineTo(0.5, 0.02)
          ..lineTo(0.8, 0.36)
          ..close(),
        purple,
      );
      canvas.drawOval(
        const Rect.fromLTWH(0.18, 0.32, 0.64, 0.1),
        Paint()..color = const Color(0xFF4A2FA8),
      );
      canvas.drawCircle(const Offset(0.5, 0.04), 0.04, tip);
      canvas.drawCircle(
        const Offset(0.42, 0.2),
        0.025,
        Paint()..color = const Color(0xFFFFC93C),
      );
    case 'hat_party':
      final pink = Paint()..color = const Color(0xFFFF6FA8);
      final stripe = Paint()..color = const Color(0xFFFFC93C);
      canvas.drawPath(
        Path()
          ..moveTo(0.28, 0.36)
          ..lineTo(0.5, 0.04)
          ..lineTo(0.72, 0.36)
          ..close(),
        pink,
      );
      canvas.drawPath(
        Path()
          ..moveTo(0.36, 0.36)
          ..lineTo(0.5, 0.12)
          ..lineTo(0.58, 0.36)
          ..close(),
        stripe,
      );
      canvas.drawCircle(
        const Offset(0.5, 0.05),
        0.05,
        Paint()..color = const Color(0xFFFFC93C),
      );
    default:
      break;
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.base, {this.hairId = '', this.hatId = ''});

  final _Look base;
  final String hairId;
  final String hatId;

  static const _ink = Color(0xFF2A1B4A);

  _Look get look {
    final shop = _shopHairOf(hairId);
    if (shop != null) {
      return _Look(
        base.background,
        base.skin,
        shop.$2,
        shop.$1,
        base.eyes,
        base.mouth,
      );
    }
    if (hatId.isNotEmpty && _isAccessoryHair(base.hair)) {
      return _Look(
        base.background,
        base.skin,
        base.hairColor,
        _Hair.none,
        base.eyes,
        base.mouth,
      );
    }
    return base;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final look = this.look;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.scale(w);

    // Fond avec un halo clair en haut à gauche.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [
            Color.lerp(look.background, Colors.white, 0.45)!,
            look.background,
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 1, 1)),
    );

    final hair = Paint()..color = look.hairColor;
    final skin = Paint()..color = look.skin;
    final shade = Paint()..color = Color.lerp(look.skin, Colors.black, 0.18)!;

    _behindHead(canvas, hair);

    // Cou et épaules.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.42, 0.7, 0.16, 0.16),
        const Radius.circular(0.04),
      ),
      shade,
    );
    canvas.drawOval(
      const Rect.fromLTWH(0.16, 0.82, 0.68, 0.4),
      Paint()..color = Color.lerp(look.background, Colors.black, 0.25)!,
    );

    // Oreilles puis tête.
    canvas.drawCircle(const Offset(0.25, 0.53), 0.06, shade);
    canvas.drawCircle(const Offset(0.75, 0.53), 0.06, shade);
    const head = Rect.fromLTWH(0.24, 0.26, 0.52, 0.54);
    canvas.drawOval(head, skin);

    _face(canvas);
    _onHead(canvas, hair);
    if (hatId.isNotEmpty) _drawShopHat(canvas, hatId);
    canvas.restore();
  }

  void _behindHead(Canvas canvas, Paint hair) {
    switch (look.hair) {
      case _Hair.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0.18, 0.2, 0.64, 0.62),
            const Radius.circular(0.26),
          ),
          hair,
        );
      case _Hair.bun:
        canvas.drawCircle(const Offset(0.5, 0.16), 0.11, hair);
      case _Hair.curly:
        for (final (x, y) in [
          (0.24, 0.5),
          (0.76, 0.5),
          (0.22, 0.38),
          (0.78, 0.38),
        ]) {
          canvas.drawCircle(Offset(x, y), 0.09, hair);
        }
      case _Hair.bunnyEars:
        final ear = Paint()..color = look.hairColor;
        final inner = Paint()..color = const Color(0xFFFFB3CF);
        for (final dx in [-0.11, 0.11]) {
          final rect = Rect.fromCenter(
            center: Offset(0.5 + dx, 0.14),
            width: 0.13,
            height: 0.34,
          );
          canvas.drawOval(rect, ear);
          canvas.drawOval(rect.deflate(0.03), inner);
        }
      default:
        break;
    }
  }

  void _onHead(Canvas canvas, Paint hair) {
    switch (look.hair) {
      case _Hair.none:
        // Petit reflet sur le crâne.
        canvas.drawOval(
          const Rect.fromLTWH(0.38, 0.29, 0.14, 0.06),
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      case _Hair.spiky:
        final path = Path()..moveTo(0.24, 0.46);
        const tips = [
          (0.27, 0.2),
          (0.36, 0.34),
          (0.42, 0.13),
          (0.5, 0.3),
          (0.58, 0.12),
          (0.64, 0.32),
          (0.74, 0.19),
        ];
        var x = 0.26;
        for (final (tx, ty) in tips) {
          path.lineTo(tx, ty);
          x += 0.075;
          path.lineTo(x, 0.34);
        }
        path
          ..lineTo(0.76, 0.46)
          ..quadraticBezierTo(0.7, 0.3, 0.5, 0.3)
          ..quadraticBezierTo(0.3, 0.3, 0.24, 0.46)
          ..close();
        canvas.drawPath(path, hair);
      case _Hair.bob || _Hair.bun || _Hair.curly:
        // Frange arrondie.
        final fringe = Path()
          ..moveTo(0.23, 0.48)
          ..quadraticBezierTo(0.22, 0.22, 0.5, 0.22)
          ..quadraticBezierTo(0.78, 0.22, 0.77, 0.48)
          ..quadraticBezierTo(0.66, 0.36, 0.5, 0.38)
          ..quadraticBezierTo(0.34, 0.36, 0.23, 0.48)
          ..close();
        canvas.drawPath(fringe, hair);
        if (look.hair == _Hair.curly) {
          for (final x in [0.32, 0.44, 0.56, 0.68]) {
            canvas.drawCircle(Offset(x, 0.26), 0.08, hair);
          }
        }
      case _Hair.cap:
        final cap = Path()
          ..moveTo(0.22, 0.42)
          ..quadraticBezierTo(0.22, 0.16, 0.5, 0.16)
          ..quadraticBezierTo(0.78, 0.16, 0.78, 0.42)
          ..close();
        canvas.drawPath(cap, hair);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(0.42, 0.37, 0.48, 0.07),
            const Radius.circular(0.035),
          ),
          Paint()..color = Color.lerp(look.hairColor, Colors.black, 0.2)!,
        );
        canvas.drawCircle(
          const Offset(0.5, 0.17),
          0.03,
          Paint()..color = Colors.white,
        );
      case _Hair.bow:
        final fringe = Path()
          ..moveTo(0.24, 0.44)
          ..quadraticBezierTo(0.26, 0.22, 0.5, 0.22)
          ..quadraticBezierTo(0.74, 0.22, 0.76, 0.44)
          ..quadraticBezierTo(0.6, 0.32, 0.5, 0.33)
          ..quadraticBezierTo(0.4, 0.32, 0.24, 0.44)
          ..close();
        canvas.drawPath(fringe, Paint()..color = const Color(0xFF7A4A2A));
        final bow = Paint()..color = look.hairColor;
        canvas.drawPath(
          Path()
            ..moveTo(0.62, 0.22)
            ..lineTo(0.5, 0.13)
            ..lineTo(0.5, 0.31)
            ..close(),
          bow,
        );
        canvas.drawPath(
          Path()
            ..moveTo(0.62, 0.22)
            ..lineTo(0.74, 0.13)
            ..lineTo(0.74, 0.31)
            ..close(),
          bow,
        );
        canvas.drawCircle(const Offset(0.62, 0.22), 0.04, bow);
      case _Hair.headphones:
        canvas.drawArc(
          const Rect.fromLTWH(0.2, 0.18, 0.6, 0.6),
          pi,
          pi,
          false,
          Paint()
            ..color = look.hairColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.06,
        );
        for (final x in [0.2, 0.8]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 0.5), width: 0.12, height: 0.2),
              const Radius.circular(0.05),
            ),
            hair,
          );
        }
      case _Hair.catEars:
        final ear = Paint()..color = look.hairColor;
        for (final dir in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(0.5 + dir * 0.08, 0.3)
              ..lineTo(0.5 + dir * 0.24, 0.12)
              ..lineTo(0.5 + dir * 0.26, 0.38)
              ..close(),
            ear,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(0.25, 0.42)
            ..quadraticBezierTo(0.3, 0.25, 0.5, 0.26)
            ..quadraticBezierTo(0.7, 0.25, 0.75, 0.42)
            ..quadraticBezierTo(0.5, 0.32, 0.25, 0.42)
            ..close(),
          ear,
        );
      case _Hair.bunnyEars:
        break;
    }
  }

  void _face(Canvas canvas) {
    final ink = Paint()..color = _ink;
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.028
      ..strokeCap = StrokeCap.round;

    // Joues roses.
    final blush = Paint()
      ..color = const Color(0xFFFF7FA8).withValues(alpha: 0.55);
    canvas.drawOval(const Rect.fromLTWH(0.29, 0.58, 0.1, 0.06), blush);
    canvas.drawOval(const Rect.fromLTWH(0.61, 0.58, 0.1, 0.06), blush);

    const left = Offset(0.4, 0.52);
    const right = Offset(0.6, 0.52);
    switch (look.eyes) {
      case _Eyes.dots:
        canvas.drawCircle(left, 0.035, ink);
        canvas.drawCircle(right, 0.035, ink);
      case _Eyes.happy:
        for (final c in [left, right]) {
          canvas.drawArc(
            Rect.fromCenter(center: c, width: 0.09, height: 0.07),
            pi,
            pi,
            false,
            line,
          );
        }
      case _Eyes.wink:
        canvas.drawCircle(left, 0.035, ink);
        canvas.drawLine(
          right.translate(-0.04, 0),
          right.translate(0.04, 0),
          line,
        );
      case _Eyes.shiny:
        for (final c in [left, right]) {
          canvas.drawCircle(c, 0.048, ink);
          canvas.drawCircle(
            c.translate(-0.015, -0.017),
            0.017,
            Paint()..color = Colors.white,
          );
        }
    }

    const mouth = Rect.fromLTWH(0.42, 0.6, 0.16, 0.1);
    switch (look.mouth) {
      case _Mouth.smile:
        canvas.drawArc(mouth, 0.15, pi - 0.3, false, line);
      case _Mouth.grin:
        canvas.drawPath(
          Path()
            ..moveTo(0.42, 0.63)
            ..quadraticBezierTo(0.5, 0.75, 0.58, 0.63)
            ..close(),
          ink,
        );
      case _Mouth.tongue:
        canvas.drawPath(
          Path()
            ..moveTo(0.42, 0.63)
            ..quadraticBezierTo(0.5, 0.74, 0.58, 0.63)
            ..close(),
          ink,
        );
        canvas.drawOval(
          const Rect.fromLTWH(0.47, 0.655, 0.07, 0.06),
          Paint()..color = const Color(0xFFFF6F8F),
        );
      case _Mouth.oh:
        canvas.drawOval(const Rect.fromLTWH(0.465, 0.62, 0.07, 0.07), ink);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.hairId != hairId ||
      oldDelegate.hatId != hatId;
}
