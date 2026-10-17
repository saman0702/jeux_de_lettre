import 'package:flutter/material.dart';

import '../data/country_flag_data.dart';

const _colors = {
  'red': Color(0xFFDE2910),
  'white': Color(0xFFFFFFFF),
  'blue': Color(0xFF0033A0),
  'sky': Color(0xFF74ACDF),
  'green': Color(0xFF009739),
  'yellow': Color(0xFFFFD100),
  'gold': Color(0xFFFFCC00),
  'black': Color(0xFF1A1A1A),
  'orange': Color(0xFFFF8A00),
  'maroon': Color(0xFF8D1B3D),
};

const _accent = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

final _notName = RegExp(r'[^a-z0-9]+');

/// Même forme que le générateur : « Côte d'Ivoire » et « cote d ivoire ».
String foldCountryName(String raw) {
  final buffer = StringBuffer();
  for (final char in raw.toLowerCase().split('')) {
    buffer.write(_accent[char] ?? char);
  }
  return buffer.toString().replaceAll(_notName, ' ').trim();
}

/// Motif du drapeau si [name] est un pays connu, sinon null.
String? flagSpecFor(String name) {
  final key = foldCountryName(name);
  if (key.isEmpty) return null;
  return countryFlagSpecs[key];
}

/// Drapeau dessiné, gratuit : il apparaît dès que le pays est reconnu.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.spec, this.width = 36});

  final String spec;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 2 / 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFFFFFFF), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(painter: _FlagPainter(spec)),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.spec);

  final String spec;

  @override
  void paint(Canvas canvas, Size size) {
    final parts = spec.split(':');
    final kind = parts.first;
    final colors = parts.length < 2
        ? const <Color>[]
        : [
            for (final name in parts[1].split(','))
              if (_colors.containsKey(name)) _colors[name]!,
          ];
    switch (kind) {
      case 'h':
        _bands(canvas, size, colors, horizontal: true);
      case 'v':
        _bands(canvas, size, colors, horizontal: false);
      case 'o':
        _disc(canvas, size, colors);
      case 'n':
        _nordic(canvas, size, colors);
      case 'c':
        _cross(canvas, size, colors);
      case 't':
        _triangle(canvas, size, colors);
      case 'p':
        _special(canvas, size, parts.length < 2 ? '' : parts[1]);
      default:
        canvas.drawRect(Offset.zero & size, Paint()..color = _colors['blue']!);
    }
  }

  void _fill(Canvas canvas, Size size, Color color) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  void _bands(Canvas canvas, Size size, List<Color> colors, {required bool horizontal}) {
    if (colors.isEmpty) return;
    final count = colors.length;
    for (var i = 0; i < count; i++) {
      final rect = horizontal
          ? Rect.fromLTWH(0, size.height * i / count, size.width, size.height / count)
          : Rect.fromLTWH(size.width * i / count, 0, size.width / count, size.height);
      canvas.drawRect(rect, Paint()..color = colors[i]);
    }
  }

  void _disc(Canvas canvas, Size size, List<Color> colors) {
    if (colors.length < 2) return;
    _fill(canvas, size, colors[0]);
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * 0.28, Paint()..color = colors[1]);
  }

  void _crossBar(Canvas canvas, Size size, Color color, double thickness, {double at = 0.5}) {
    final paint = Paint()..color = color;
    final bar = size.shortestSide * thickness;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * at, size.height / 2),
        width: bar,
        height: size.height,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * at, size.height / 2),
        width: size.width,
        height: bar,
      ),
      paint,
    );
  }

  void _nordic(Canvas canvas, Size size, List<Color> colors) {
    if (colors.length < 2) return;
    _fill(canvas, size, colors[0]);
    if (colors[1] != _colors['white']) {
      _crossBar(canvas, size, _colors['white']!, 0.32, at: 0.35);
    }
    _crossBar(canvas, size, colors[1], 0.16, at: 0.35);
  }

  void _cross(Canvas canvas, Size size, List<Color> colors) {
    if (colors.length < 2) return;
    _fill(canvas, size, colors[0]);
    _crossBar(canvas, size, colors[1], 0.22);
  }

  void _triangle(Canvas canvas, Size size, List<Color> colors) {
    if (colors.length < 2) return;
    _bands(canvas, size, colors.sublist(1), horizontal: true);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.45, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = colors.first);
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _special(Canvas canvas, Size size, String code) {
    final w = size.width;
    final h = size.height;
    switch (code) {
      case 'us':
        _bands(canvas, size, [
          for (var i = 0; i < 7; i++) ...[_colors['red']!, _colors['white']!],
        ].take(13).toList(), horizontal: true);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w * 0.4, h * 7 / 13),
          Paint()..color = _colors['blue']!,
        );
        _star(canvas, Offset(w * 0.2, h * 0.18), h * 0.06, _colors['white']!);
      case 'gb':
        _fill(canvas, size, _colors['blue']!);
        final white = Paint()
          ..color = _colors['white']!
          ..strokeWidth = h * 0.18
          ..style = PaintingStyle.stroke;
        final red = Paint()
          ..color = _colors['red']!
          ..strokeWidth = h * 0.08
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset.zero, Offset(w, h), white);
        canvas.drawLine(Offset(w, 0), Offset(0, h), white);
        canvas.drawLine(Offset.zero, Offset(w, h), red);
        canvas.drawLine(Offset(w, 0), Offset(0, h), red);
        _crossBar(canvas, size, _colors['white']!, 0.34);
        _crossBar(canvas, size, _colors['red']!, 0.18);
      case 'br':
        _fill(canvas, size, _colors['green']!);
        final diamond = Path()
          ..moveTo(w / 2, h * 0.08)
          ..lineTo(w * 0.92, h / 2)
          ..lineTo(w / 2, h * 0.92)
          ..lineTo(w * 0.08, h / 2)
          ..close();
        canvas.drawPath(diamond, Paint()..color = _colors['yellow']!);
        canvas.drawCircle(size.center(Offset.zero), h * 0.22, Paint()..color = _colors['blue']!);
      case 'au':
        _fill(canvas, size, _colors['blue']!);
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, w * 0.5, h * 0.55));
        canvas.scale(0.5, 0.55);
        _special(canvas, Size(w, h), 'gb');
        canvas.restore();
        _star(canvas, Offset(w * 0.75, h * 0.55), h * 0.08, _colors['white']!);
      case 'za':
        _fill(canvas, size, _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), Paint()..color = _colors['blue']!);
        final yellow = Path()
          ..moveTo(0, 0)
          ..lineTo(w * 0.35, h / 2)
          ..lineTo(0, h)
          ..lineTo(w, h * 0.7)
          ..lineTo(w, h * 0.3)
          ..close();
        canvas.drawPath(yellow, Paint()..color = _colors['yellow']!);
        final green = Path()
          ..moveTo(0, h * 0.15)
          ..lineTo(w * 0.28, h / 2)
          ..lineTo(0, h * 0.85)
          ..lineTo(w, h * 0.62)
          ..lineTo(w, h * 0.38)
          ..close();
        canvas.drawPath(green, Paint()..color = _colors['green']!);
        final black = Path()
          ..moveTo(0, h * 0.28)
          ..lineTo(w * 0.16, h / 2)
          ..lineTo(0, h * 0.72)
          ..close();
        canvas.drawPath(black, Paint()..color = _colors['black']!);
      case 'cl':
      case 'cu':
        _bands(
          canvas,
          size,
          code == 'cl'
              ? [_colors['white']!, _colors['red']!]
              : [
                  _colors['blue']!,
                  _colors['white']!,
                  _colors['blue']!,
                  _colors['white']!,
                  _colors['blue']!,
                ],
          horizontal: true,
        );
        final hoist = code == 'cl' ? Rect.fromLTWH(0, 0, w * 0.4, h / 2) : null;
        if (hoist != null) {
          canvas.drawRect(hoist, Paint()..color = _colors['blue']!);
        }
        final tri = Path()
          ..moveTo(0, 0)
          ..lineTo(w * (code == 'cl' ? 0.28 : 0.42), h / 2)
          ..lineTo(0, h)
          ..close();
        if (code == 'cu') canvas.drawPath(tri, Paint()..color = _colors['red']!);
        _star(
          canvas,
          code == 'cl' ? Offset(w * 0.2, h * 0.25) : Offset(w * 0.16, h / 2),
          h * 0.08,
          _colors['white']!,
        );
      case 'cz':
        _bands(canvas, size, [_colors['white']!, _colors['red']!], horizontal: true);
        _triangle(canvas, size, [_colors['blue']!, _colors['white']!, _colors['red']!]);
      case 'gr':
        _bands(canvas, size, [
          for (var i = 0; i < 5; i++) ...[_colors['blue']!, _colors['white']!],
        ].take(9).toList(), horizontal: true);
        canvas.drawRect(Rect.fromLTWH(0, 0, h * 0.55, h * 0.55), Paint()..color = _colors['blue']!);
        _crossBar(canvas, Size(h * 0.55, h * 0.55), _colors['white']!, 0.22);
      case 'ae':
      case 'kw':
      case 'om':
        final bands = code == 'kw'
            ? [_colors['green']!, _colors['white']!, _colors['red']!]
            : code == 'om'
            ? [_colors['white']!, _colors['red']!, _colors['green']!]
            : [_colors['green']!, _colors['white']!, _colors['black']!];
        _bands(canvas, size, bands, horizontal: true);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w * 0.28, h),
          Paint()..color = code == 'kw' ? _colors['black']! : _colors['red']!,
        );
      case 'bj':
      case 'mg':
      case 'gw':
        canvas.drawRect(Rect.fromLTWH(w * 0.38, 0, w, h / 2), Paint()..color = code == 'gw' ? _colors['yellow']! : _colors['red']!);
        canvas.drawRect(
          Rect.fromLTWH(w * 0.38, h / 2, w, h / 2),
          Paint()..color = _colors['green']!,
        );
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w * 0.38, h),
          Paint()..color = code == 'mg' ? _colors['white']! : code == 'gw' ? _colors['red']! : _colors['green']!,
        );
      case 'cf':
        _bands(canvas, size, [_colors['blue']!, _colors['white']!, _colors['green']!, _colors['yellow']!], horizontal: true);
        canvas.drawRect(Rect.fromLTWH(w * 0.4, 0, w * 0.2, h), Paint()..color = _colors['red']!);
      case 'kr':
        _fill(canvas, size, _colors['white']!);
        canvas.drawArc(
          Rect.fromCircle(center: size.center(Offset.zero), radius: h * 0.22),
          -1.2,
          3.14,
          true,
          Paint()..color = _colors['red']!,
        );
        canvas.drawArc(
          Rect.fromCircle(center: size.center(Offset.zero), radius: h * 0.22),
          1.9,
          3.14,
          true,
          Paint()..color = _colors['blue']!,
        );
      case 'jm':
        _fill(canvas, size, _colors['yellow']!);
        final green = Paint()..color = _colors['green']!;
        canvas.drawPath(Path()..moveTo(w * 0.15, 0)..lineTo(w * 0.85, 0)..lineTo(w / 2, h * 0.38)..close(), green);
        canvas.drawPath(Path()..moveTo(w * 0.15, h)..lineTo(w * 0.85, h)..lineTo(w / 2, h * 0.62)..close(), green);
        final black = Paint()..color = _colors['black']!;
        canvas.drawPath(Path()..moveTo(0, h * 0.18)..lineTo(0, h * 0.82)..lineTo(w * 0.32, h / 2)..close(), black);
        canvas.drawPath(Path()..moveTo(w, h * 0.18)..lineTo(w, h * 0.82)..lineTo(w * 0.68, h / 2)..close(), black);
      case 'pa':
        canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h / 2), Paint()..color = _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, h / 2, w / 2, h / 2), Paint()..color = _colors['blue']!);
        canvas.drawRect(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2), Paint()..color = _colors['white']!);
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), Paint()..color = _colors['white']!);
      case 'ph':
        _bands(canvas, size, [_colors['blue']!, _colors['red']!], horizontal: true);
        _triangle(canvas, size, [_colors['white']!, _colors['blue']!, _colors['red']!]);
      case 'do':
        _fill(canvas, size, _colors['white']!);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h * 0.4), Paint()..color = _colors['blue']!);
        canvas.drawRect(Rect.fromLTWH(w * 0.6, h * 0.6, w * 0.4, h * 0.4), Paint()..color = _colors['blue']!);
        canvas.drawRect(Rect.fromLTWH(w * 0.6, 0, w * 0.4, h * 0.4), Paint()..color = _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w * 0.4, h * 0.4), Paint()..color = _colors['red']!);
      case 'sc':
        final rays = [_colors['blue']!, _colors['yellow']!, _colors['red']!, _colors['white']!, _colors['green']!];
        for (var i = 0; i < rays.length; i++) {
          final path = Path()
            ..moveTo(0, h)
            ..lineTo(w * (i + 1) / rays.length, 0)
            ..lineTo(w * i / rays.length, 0)
            ..close();
          canvas.drawPath(path, Paint()..color = rays[i]);
        }
      case 'tg':
        _bands(canvas, size, [_colors['green']!, _colors['yellow']!, _colors['green']!, _colors['yellow']!, _colors['green']!], horizontal: true);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h * 0.6), Paint()..color = _colors['red']!);
        _star(canvas, Offset(w * 0.2, h * 0.3), h * 0.08, _colors['white']!);
      case 'to':
      case 'ws':
        _fill(canvas, size, _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.45, h * 0.55), Paint()..color = code == 'ws' ? _colors['blue']! : _colors['white']!);
        if (code == 'to') {
          _crossBar(canvas, Size(w * 0.45, h * 0.55), _colors['red']!, 0.28);
        } else {
          _star(canvas, Offset(w * 0.22, h * 0.28), h * 0.08, _colors['white']!);
        }
      case 'tw':
        _fill(canvas, size, _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.45, h * 0.55), Paint()..color = _colors['blue']!);
        _star(canvas, Offset(w * 0.22, h * 0.27), h * 0.1, _colors['white']!);
      case 'tt':
        _fill(canvas, size, _colors['red']!);
        final band = Paint()
          ..color = _colors['white']!
          ..strokeWidth = h * 0.38
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, h), Offset(w, 0), band);
        band
          ..color = _colors['black']!
          ..strokeWidth = h * 0.18;
        canvas.drawLine(Offset(0, h), Offset(w, 0), band);
      case 'tz':
      case 'cg':
      case 'cd':
      case 'na':
        final top = code == 'tz' || code == 'na'
            ? _colors['green']!
            : code == 'cd'
            ? _colors['sky']!
            : _colors['green']!;
        final bottom = code == 'cg' ? _colors['red']! : code == 'cd' ? _colors['sky']! : _colors['blue']!;
        _fill(canvas, size, bottom);
        canvas.drawPath(
          Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(0, h)..close(),
          Paint()..color = top,
        );
        final slash = Paint()
          ..color = code == 'cd' ? _colors['yellow']! : _colors['yellow']!
          ..strokeWidth = h * 0.28
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(0, h), Offset(w, 0), slash);
        if (code != 'cg') {
          slash
            ..color = _colors['black']!
            ..strokeWidth = h * 0.12;
          canvas.drawLine(Offset(0, h), Offset(w, 0), slash);
        }
      case 'tl':
        _fill(canvas, size, _colors['red']!);
        canvas.drawPath(
          Path()..moveTo(0, 0)..lineTo(w * 0.62, h / 2)..lineTo(0, h)..close(),
          Paint()..color = _colors['yellow']!,
        );
        canvas.drawPath(
          Path()..moveTo(0, 0)..lineTo(w * 0.4, h / 2)..lineTo(0, h)..close(),
          Paint()..color = _colors['black']!,
        );
      case 'uy':
        _bands(canvas, size, [
          for (var i = 0; i < 5; i++) ...[_colors['white']!, _colors['blue']!],
        ].take(9).toList(), horizontal: true);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h * 0.5), Paint()..color = _colors['white']!);
        _star(canvas, Offset(w * 0.2, h * 0.25), h * 0.1, _colors['yellow']!);
      case 'np':
        _fill(canvas, size, _colors['blue']!);
        canvas.drawPath(
          Path()..moveTo(w * 0.15, h * 0.05)..lineTo(w * 0.8, h * 0.32)..lineTo(w * 0.15, h * 0.48)..close(),
          Paint()..color = _colors['red']!,
        );
        canvas.drawPath(
          Path()..moveTo(w * 0.15, h * 0.42)..lineTo(w * 0.85, h * 0.7)..lineTo(w * 0.15, h * 0.95)..close(),
          Paint()..color = _colors['red']!,
        );
      case 'bt':
        canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(0, h)..close(), Paint()..color = _colors['yellow']!);
        canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(0, h)..close(), Paint()..color = _colors['orange']!);
      case 'ba':
        _fill(canvas, size, _colors['blue']!);
        canvas.drawPath(
          Path()..moveTo(w * 0.3, 0)..lineTo(w, 0)..lineTo(w, h)..close(),
          Paint()..color = _colors['yellow']!,
        );
      case 'bi':
        _fill(canvas, size, _colors['red']!);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.35, w, h * 0.3), Paint()..color = _colors['white']!);
        canvas.drawRect(Rect.fromLTWH(0, h * 0.65, w, h * 0.35), Paint()..color = _colors['green']!);
        canvas.drawLine(
          Offset.zero,
          Offset(w, h),
          Paint()
            ..color = _colors['white']!
            ..strokeWidth = h * 0.12,
        );
        canvas.drawLine(
          Offset(w, 0),
          Offset(0, h),
          Paint()
            ..color = _colors['white']!
            ..strokeWidth = h * 0.12,
        );
      case 'km':
        _bands(canvas, size, [_colors['yellow']!, _colors['white']!, _colors['red']!, _colors['blue']!], horizontal: true);
        _triangle(canvas, size, [_colors['green']!, _colors['yellow']!, _colors['white']!, _colors['red']!]);
      case 'er':
        _bands(canvas, size, [_colors['red']!, _colors['blue']!], horizontal: true);
        _triangle(canvas, size, [_colors['green']!, _colors['red']!, _colors['blue']!]);
      case 'ag':
        _fill(canvas, size, _colors['blue']!);
        canvas.drawPath(
          Path()..moveTo(0, 0)..lineTo(w / 2, h * 0.7)..lineTo(0, h)..close(),
          Paint()..color = _colors['red']!,
        );
        canvas.drawPath(
          Path()..moveTo(w, 0)..lineTo(w / 2, h * 0.7)..lineTo(w, h)..close(),
          Paint()..color = _colors['red']!,
        );
        canvas.drawPath(
          Path()..moveTo(w * 0.2, h)..lineTo(w / 2, h * 0.35)..lineTo(w * 0.8, h)..close(),
          Paint()..color = _colors['white']!,
        );
        _star(canvas, Offset(w / 2, h * 0.42), h * 0.1, _colors['yellow']!);
      case 'my':
        _bands(canvas, size, [
          for (var i = 0; i < 7; i++) ...[_colors['red']!, _colors['white']!],
        ].take(14).toList(), horizontal: true);
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.5, h * 0.5), Paint()..color = _colors['blue']!);
        _star(canvas, Offset(w * 0.22, h * 0.22), h * 0.08, _colors['yellow']!);
      case 'pg':
        canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(w, h)..close(), Paint()..color = _colors['black']!);
        canvas.drawPath(Path()..moveTo(0, 0)..lineTo(0, h)..lineTo(w, h)..close(), Paint()..color = _colors['red']!);
      case 'kn':
        canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(0, h)..close(), Paint()..color = _colors['green']!);
        canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(0, h)..close(), Paint()..color = _colors['red']!);
        canvas.drawLine(
          Offset(0, h),
          Offset(w, 0),
          Paint()
            ..color = _colors['yellow']!
            ..strokeWidth = h * 0.28,
        );
        canvas.drawLine(
          Offset(0, h),
          Offset(w, 0),
          Paint()
            ..color = _colors['black']!
            ..strokeWidth = h * 0.12,
        );
      case 'sb':
        canvas.drawPath(Path()..moveTo(0, 0)..lineTo(w, 0)..lineTo(0, h)..close(), Paint()..color = _colors['blue']!);
        canvas.drawPath(Path()..moveTo(w, 0)..lineTo(w, h)..lineTo(0, h)..close(), Paint()..color = _colors['green']!);
        canvas.drawLine(
          Offset(0, h),
          Offset(w, 0),
          Paint()
            ..color = _colors['yellow']!
            ..strokeWidth = h * 0.16,
        );
      case 'lk':
        _fill(canvas, size, _colors['yellow']!);
        canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.1, w * 0.7, h * 0.8), Paint()..color = _colors['maroon']!);
        canvas.drawRect(Rect.fromLTWH(w * 0.22, h * 0.1, w * 0.18, h * 0.8), Paint()..color = _colors['green']!);
        canvas.drawRect(Rect.fromLTWH(w * 0.55, h * 0.1, w * 0.22, h * 0.8), Paint()..color = _colors['orange']!);
      default:
        _fill(canvas, size, _colors['blue']!);
    }
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => oldDelegate.spec != spec;
}
