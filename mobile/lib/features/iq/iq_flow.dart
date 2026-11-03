import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../l10n/app_localizations.dart';

const _flowColors = [
  AppColors.red,
  AppColors.cyan,
  AppColors.yellow,
  AppColors.green,
  AppColors.purple,
  AppColors.orange,
];

/// Gagne immédiatement l'arène de gestes pour que le ListView parent
/// ne vole pas les glissés verticaux pendant le dessin.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class IqFlowPair {
  const IqFlowPair({required this.color, required this.a, required this.b});

  factory IqFlowPair.fromJson(Map<String, dynamic> json) => IqFlowPair(
    color: json['color'] as int? ?? 0,
    a: ((json['a'] as List)[0] as int, (json['a'] as List)[1] as int),
    b: ((json['b'] as List)[0] as int, (json['b'] as List)[1] as int),
  );

  final int color;
  final (int, int) a;
  final (int, int) b;
}

class IqFlow {
  const IqFlow({required this.size, required this.pairs, this.solutions});

  factory IqFlow.fromJson(Map<String, dynamic> json) => IqFlow(
    size: json['size'] as int,
    pairs: [
      for (final p in json['pairs'] as List)
        IqFlowPair.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
    solutions: json['solutions'] == null
        ? null
        : [
            for (final path in json['solutions'] as List)
              [
                for (final c in path as List)
                  ((c as List)[0] as int, c[1] as int),
              ],
          ],
  );

  final int size;
  final List<IqFlowPair> pairs;
  final List<List<(int, int)>>? solutions;

  Map<String, dynamic> toJson() => {
    'size': size,
    'pairs': [
      for (final p in pairs)
        {
          'color': p.color,
          'a': [p.a.$1, p.a.$2],
          'b': [p.b.$1, p.b.$2],
        },
    ],
    if (solutions != null)
      'solutions': [
        for (final path in solutions!)
          [
            for (final c in path) [c.$1, c.$2],
          ],
      ],
  };

  /// Parse une réponse JSON `[[[r,c],…], …]` ; null si invalide.
  static List<List<(int, int)>>? parsePaths(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return [
        for (final path in decoded)
          [
            for (final c in path as List)
              ((c as List)[0] as int, c[1] as int),
          ],
      ];
    } catch (_) {
      return null;
    }
  }

  bool isValid(String raw) {
    final paths = parsePaths(raw);
    return paths != null && _validPaths(paths);
  }

  bool _validPaths(List<List<(int, int)>> paths) {
    if (paths.length != pairs.length) return false;
    final occupied = <(int, int)>{};
    for (var i = 0; i < pairs.length; i++) {
      final path = paths[i];
      final pair = pairs[i];
      if (path.isEmpty || path.first != pair.a || path.last != pair.b) {
        return false;
      }
      for (final cell in path) {
        if (cell.$1 < 0 ||
            cell.$1 >= size ||
            cell.$2 < 0 ||
            cell.$2 >= size ||
            !occupied.add(cell)) {
          return false;
        }
      }
      for (var j = 0; j + 1 < path.length; j++) {
        final a = path[j];
        final b = path[j + 1];
        if ((a.$1 - b.$1).abs() + (a.$2 - b.$2).abs() != 1) return false;
      }
    }
    return true;
  }
}

/// Planche Flow : on part d'un point coloré, on glisse case par case.
class IqFlowBoard extends StatefulWidget {
  const IqFlowBoard({
    super.key,
    required this.flow,
    required this.onDone,
    this.enabled = true,
  });

  final IqFlow flow;
  final ValueChanged<String> onDone;
  final bool enabled;

  @override
  State<IqFlowBoard> createState() => _IqFlowBoardState();
}

class _IqFlowBoardState extends State<IqFlowBoard> {
  late List<List<(int, int)>> _paths = [
    for (final p in widget.flow.pairs) [p.a],
  ];
  int? _active;
  bool _sent = false;

  IqFlow get _flow => widget.flow;

  Color _colorOf(int pairIndex) =>
      _flowColors[_flow.pairs[pairIndex].color % _flowColors.length];

  int? _pairAt((int, int) cell) {
    for (var i = 0; i < _flow.pairs.length; i++) {
      final p = _flow.pairs[i];
      if (p.a == cell || p.b == cell) return i;
    }
    return null;
  }

  bool _occupied((int, int) cell, {int? except}) {
    for (var i = 0; i < _paths.length; i++) {
      if (except == i) continue;
      if (_paths[i].contains(cell)) return true;
    }
    return false;
  }

  (int, int) _goal(int i) {
    final pair = _flow.pairs[i];
    final start = _paths[i].isEmpty ? pair.a : _paths[i].first;
    return start == pair.a ? pair.b : pair.a;
  }

  bool get _complete {
    for (var i = 0; i < _flow.pairs.length; i++) {
      final path = _paths[i];
      final pair = _flow.pairs[i];
      if (path.length < 2) return false;
      final ends = {path.first, path.last};
      if (!ends.contains(pair.a) || !ends.contains(pair.b)) return false;
    }
    return true;
  }

  /// Chemins normalisés a → b pour le serveur / validation.
  List<List<(int, int)>> _normalized() => [
    for (var i = 0; i < _flow.pairs.length; i++)
      _paths[i].first == _flow.pairs[i].a
          ? List<(int, int)>.of(_paths[i])
          : _paths[i].reversed.toList(),
  ];

  void _submitIfDone() {
    if (!_complete || _sent) return;
    _sent = true;
    final paths = _normalized();
    widget.onDone(
      jsonEncode([
        for (final path in paths)
          [
            for (final c in path) [c.$1, c.$2],
          ],
      ]),
    );
  }

  bool _pairDone(int i) {
    final path = _paths[i];
    final pair = _flow.pairs[i];
    if (path.length < 2) return false;
    final ends = {path.first, path.last};
    return ends.contains(pair.a) && ends.contains(pair.b);
  }

  /// Cases entre [from] et [to] (glissé rapide : le doigt saute des cases).
  Iterable<(int, int)> _stepsBetween((int, int) from, (int, int) to) sync* {
    var r = from.$1;
    var c = from.$2;
    while (r != to.$1 || c != to.$2) {
      if (r != to.$1) r += to.$1 > r ? 1 : -1;
      else if (c != to.$2) c += to.$2 > c ? 1 : -1;
      yield (r, c);
    }
  }

  void _visit((int, int) cell) {
    if (!widget.enabled || _sent) return;
    final endpoint = _pairAt(cell);

    if (_active == null) {
      // Reprendre un trait incomplet en touchant sa pointe.
      for (var i = 0; i < _paths.length; i++) {
        if (!_pairDone(i) &&
            _paths[i].length >= 2 &&
            _paths[i].last == cell) {
          setState(() => _active = i);
          return;
        }
      }
      if (endpoint == null) return;
      setState(() {
        _active = endpoint;
        // Nouveau départ (ou recommencer cette couleur) depuis ce bout.
        _paths[endpoint] = [cell];
      });
      return;
    }

    final i = _active!;
    // Autre couleur : on bascule (sans exiger d'être voisin du trait en cours).
    if (endpoint != null && endpoint != i) {
      setState(() {
        _active = endpoint;
        _paths[endpoint] = [cell];
      });
      return;
    }

    final path = _paths[i];
    final last = path.last;
    if (cell == last) return;

    // Une case à la fois, en comblant les sauts du doigt.
    for (final step in _stepsBetween(last, cell)) {
      if (!_extend(i, step)) break;
    }
  }

  /// Allonge (ou recule) le chemin actif d'une case voisine. false = bloqué.
  bool _extend(int i, (int, int) cell) {
    final path = _paths[i];
    final last = path.last;
    if (cell == last) return true;
    if ((cell.$1 - last.$1).abs() + (cell.$2 - last.$2).abs() != 1) {
      return false;
    }
    final goal = _goal(i);
    final other = _pairAt(cell);
    if (other != null && other != i && cell != goal) return false;
    if (_occupied(cell, except: i) && cell != goal) return false;
    if (path.length >= 2 && path[path.length - 2] == cell) {
      setState(() => _paths[i] = path.sublist(0, path.length - 1));
      return true;
    }
    if (path.contains(cell) && cell != goal) return false;
    GameFeedbackScope.of(context).play(Sfx.key);
    setState(() {
      _paths[i] = [...path, cell];
      if (cell == goal) _active = null;
    });
    _submitIfDone();
    return cell != goal;
  }

  void _reset() => setState(() {
    _paths = [
      for (final p in _flow.pairs) [p.a],
    ];
    _active = null;
    _sent = false;
  });

  (int, int)? _cellAt(Offset local, double cell) {
    final n = _flow.size;
    final r = (local.dy / cell).floor();
    final c = (local.dx / cell).floor();
    if (r < 0 || r >= n || c < 0 || c >= n) return null;
    return (r, c);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final n = _flow.size;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / n;
              return RawGestureDetector(
                key: const Key('iq_flow_board'),
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  _EagerPanGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _EagerPanGestureRecognizer
                      >(
                    () => _EagerPanGestureRecognizer(),
                    (instance) {
                      if (!widget.enabled) {
                        instance.onStart = null;
                        instance.onUpdate = null;
                        return;
                      }
                      instance.onStart = (d) {
                        final at = _cellAt(d.localPosition, cell);
                        if (at != null) _visit(at);
                      };
                      instance.onUpdate = (d) {
                        final at = _cellAt(d.localPosition, cell);
                        if (at != null) _visit(at);
                      };
                    },
                  ),
                },
                child: CustomPaint(
                  painter: _FlowPainter(
                    flow: _flow,
                    paths: _paths,
                    active: _active,
                    cell: cell,
                    colorOf: _colorOf,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        CandyButton(
          key: const Key('iq_flow_reset'),
          label: l10n.iqTraceRestart,
          icon: Icons.replay_rounded,
          color: AppColors.white,
          height: 40,
          fontSize: 14,
          onPressed: !widget.enabled ? null : _reset,
        ),
      ],
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.flow,
    required this.paths,
    required this.active,
    required this.cell,
    this.colorOf,
  });

  final IqFlow flow;
  final List<List<(int, int)>> paths;
  final int? active;
  final double cell;
  final Color Function(int pairIndex)? colorOf;

  Color _pairColor(int i) =>
      colorOf?.call(i) ??
      _flowColors[flow.pairs[i].color % _flowColors.length];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFDCD3F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var r = 0; r <= flow.size; r++) {
      canvas.drawLine(
        Offset(0, r * cell),
        Offset(size.width, r * cell),
        grid,
      );
      canvas.drawLine(
        Offset(r * cell, 0),
        Offset(r * cell, size.height),
        grid,
      );
    }
    Offset center((int, int) c) =>
        Offset((c.$2 + 0.5) * cell, (c.$1 + 0.5) * cell);

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.length < 2) continue;
      final paint = Paint()
        ..color = _pairColor(i)
        ..strokeWidth = cell * 0.35
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      for (var j = 0; j + 1 < path.length; j++) {
        canvas.drawLine(center(path[j]), center(path[j + 1]), paint);
      }
    }
    for (var i = 0; i < flow.pairs.length; i++) {
      final pair = flow.pairs[i];
      final color = _pairColor(i);
      for (final c in [pair.a, pair.b]) {
        canvas.drawCircle(
          center(c),
          cell * 0.32,
          Paint()..color = color,
        );
        canvas.drawCircle(
          center(c),
          cell * 0.32,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = AppColors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) => true;
}

/// Grille flow en lecture seule (solution ou réponse du joueur).
/// [animate] dessine les chemins segment par segment pour faire comprendre.
class IqFlowView extends StatefulWidget {
  const IqFlowView({
    super.key,
    required this.flow,
    this.paths,
    this.animate = false,
  });

  final IqFlow flow;

  /// Chemins à afficher ; sinon `flow.solutions`.
  final List<List<(int, int)>>? paths;

  /// Simulation progressive (écran de correction).
  final bool animate;

  @override
  State<IqFlowView> createState() => _IqFlowViewState();
}

class _IqFlowViewState extends State<IqFlowView>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  List<List<(int, int)>>? get _full =>
      widget.paths ?? widget.flow.solutions;

  int get _segmentCount {
    final paths = _full;
    if (paths == null) return 0;
    var n = 0;
    for (final path in paths) {
      if (path.length >= 2) n += path.length - 1;
    }
    return n;
  }

  @override
  void initState() {
    super.initState();
    if (widget.animate && _segmentCount > 0) {
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 280 + _segmentCount * 160),
      )..forward();
    }
  }

  @override
  void didUpdateWidget(covariant IqFlowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate ||
        widget.paths != oldWidget.paths ||
        widget.flow != oldWidget.flow) {
      _controller?.dispose();
      _controller = null;
      if (widget.animate && _segmentCount > 0) {
        _controller = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 280 + _segmentCount * 160),
        )..forward();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<List<(int, int)>> _visible(double t) {
    final full = _full!;
    if (!widget.animate || _controller == null) return full;
    final total = _segmentCount;
    if (total == 0) return full;
    final shown = (t * total).floor().clamp(0, total);
    if (shown >= total) return full;
    final out = <List<(int, int)>>[];
    var left = shown;
    for (final path in full) {
      if (path.isEmpty) {
        out.add(const []);
        continue;
      }
      if (path.length < 2 || left <= 0) {
        out.add([path.first]);
        continue;
      }
      final segs = path.length - 1;
      if (left >= segs) {
        out.add(List<(int, int)>.of(path));
        left -= segs;
      } else {
        out.add(path.sublist(0, left + 1));
        left = 0;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final full = _full;
    if (full == null) return const SizedBox.shrink();
    final anim = _controller;
    Widget board(List<List<(int, int)>> paths) => AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cell = constraints.maxWidth / widget.flow.size;
          return CustomPaint(
            painter: _FlowPainter(
              flow: widget.flow,
              paths: paths,
              active: null,
              cell: cell,
            ),
          );
        },
      ),
    );
    if (anim == null) return board(full);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => board(_visible(anim.value)),
    );
  }
}
