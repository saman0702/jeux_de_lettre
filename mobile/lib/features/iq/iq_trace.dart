import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../l10n/app_localizations.dart';

/// Gagne l'arène face au scroll parent (dessin vertical).
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Figure à tracer d'un seul trait : des points (sur une petite grille) et
/// des lignes entre eux.
class IqTrace {
  const IqTrace({
    required this.points,
    required this.edges,
    this.numbered = false,
    this.ordered = false,
  });

  factory IqTrace.fromJson(Map<String, dynamic> json) => IqTrace(
    points: [
      for (final p in json['points'] as List)
        ((p as List)[0] as int, p[1] as int),
    ],
    edges: [
      for (final e in json['edges'] as List)
        ((e as List)[0] as int, e[1] as int),
    ],
    numbered: json['numbered'] as bool? ?? false,
    ordered: json['ordered'] as bool? ?? false,
  );

  final List<(int, int)> points;
  final List<(int, int)> edges;

  /// Afficher 1, 2, 3… sur les points.
  final bool numbered;

  /// Relier uniquement dans l'ordre des numéros.
  final bool ordered;

  /// Ligne entre [a] et [b], ou -1.
  int edgeBetween(int a, int b) => edges.indexWhere(
    (e) => (e.$1 == a && e.$2 == b) || (e.$1 == b && e.$2 == a),
  );

  /// Même règle que le serveur : chaque ligne une seule fois, sans saut.
  bool isValid(String raw) {
    final path = raw.split('-').map(int.tryParse).toList();
    if (path.contains(null)) return false;
    if (ordered) {
      final closed = edgeBetween(0, points.length - 1) >= 0;
      final expected = [
        for (var i = 0; i < points.length; i++) i,
        if (closed) 0,
      ];
      if (path.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (path[i] != expected[i]) return false;
      }
      return true;
    }
    if (path.length != edges.length + 1) return false;
    final used = <int>{};
    for (var i = 0; i + 1 < path.length; i++) {
      final edge = edgeBetween(path[i]!, path[i + 1]!);
      if (edge < 0 || !used.add(edge)) return false;
    }
    return used.length == edges.length;
  }

  int get _cols => points.map((p) => p.$1).reduce(max) + 1;
  int get _rows => points.map((p) => p.$2).reduce(max) + 1;

  /// Hauteur pour une largeur donnée (la grille garde ses proportions).
  double heightFor(double width) =>
      _pad * 2 + (width - _pad * 2) * max(1, _rows - 1) / max(1, _cols - 1);

  static const _pad = 26.0;

  /// Position du point [i] dans une planche de taille [size].
  Offset offsetOf(int i, Size size) {
    final (x, y) = points[i];
    final w = size.width - _pad * 2;
    final h = size.height - _pad * 2;
    return Offset(
      _pad + (_cols == 1 ? w / 2 : w * x / (_cols - 1)),
      _pad + (_rows == 1 ? h / 2 : h * y / (_rows - 1)),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({
    required this.trace,
    required this.path,
    this.start,
    this.solved = false,
  });

  final IqTrace trace;
  final List<int> path;
  final int? start;
  final bool solved;

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Paint()
      ..color = const Color(0xFFDCD3F2)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final done = Paint()
      ..color = solved ? AppColors.green : AppColors.purple
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in trace.edges) {
      canvas.drawLine(trace.offsetOf(a, size), trace.offsetOf(b, size), todo);
    }
    for (var i = 0; i + 1 < path.length; i++) {
      canvas.drawLine(
        trace.offsetOf(path[i], size),
        trace.offsetOf(path[i + 1], size),
        done,
      );
    }
    final current = path.isEmpty ? null : path.last;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < trace.points.length; i++) {
      final c = trace.offsetOf(i, size);
      final hinted = start == i && path.isEmpty;
      final r = i == current || hinted || trace.numbered ? 14.0 : 10.0;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = i == current
              ? AppColors.yellow
              : (hinted ? AppColors.orange : AppColors.white),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.purpleDeep,
      );
      if (trace.numbered) {
        tp.text = TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: AppColors.purpleDeep,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        );
        tp.layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.path.length != path.length || old.start != start;
}

/// La figure dessinée (correction : la solution en vert).
/// [animate] relie les points un à un pour faire comprendre le parcours.
class IqTraceView extends StatefulWidget {
  const IqTraceView({
    super.key,
    required this.trace,
    this.path = const [],
    this.animate = false,
  });

  final IqTrace trace;
  final List<int> path;
  final bool animate;

  @override
  State<IqTraceView> createState() => _IqTraceViewState();
}

class _IqTraceViewState extends State<IqTraceView>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  int get _segments =>
      widget.path.length < 2 ? 0 : widget.path.length - 1;

  @override
  void initState() {
    super.initState();
    if (widget.animate && _segments > 0) {
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 280 + _segments * 180),
      )..forward();
    }
  }

  @override
  void didUpdateWidget(covariant IqTraceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate ||
        widget.path.length != oldWidget.path.length) {
      _controller?.dispose();
      _controller = null;
      if (widget.animate && _segments > 0) {
        _controller = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 280 + _segments * 180),
        )..forward();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<int> _visible(double t) {
    if (!widget.animate || _controller == null || _segments == 0) {
      return widget.path;
    }
    final shown = (t * _segments).floor().clamp(0, _segments);
    if (shown >= _segments) return widget.path;
    return widget.path.sublist(0, shown + 1);
  }

  @override
  Widget build(BuildContext context) {
    final anim = _controller;
    Widget board(List<int> path) => LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, 260.0);
        return Center(
          child: SizedBox(
            width: width,
            height: widget.trace.heightFor(width),
            child: CustomPaint(
              painter: _TracePainter(
                trace: widget.trace,
                path: path,
                solved: true,
              ),
            ),
          ),
        );
      },
    );
    if (anim == null) return board(widget.path);
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) => board(_visible(anim.value)),
    );
  }
}

/// Planche à tracer : on glisse le doigt de point en point (ou on les touche
/// un par un). Quand toutes les lignes sont passées, la réponse part.
class IqTraceBoard extends StatefulWidget {
  const IqTraceBoard({
    super.key,
    required this.trace,
    required this.onDone,
    this.enabled = true,
    this.start,
  });

  final IqTrace trace;
  final ValueChanged<String> onDone;
  final bool enabled;

  /// Indice : le point d'où partir.
  final int? start;

  @override
  State<IqTraceBoard> createState() => _IqTraceBoardState();
}

class _IqTraceBoardState extends State<IqTraceBoard> {
  final List<int> _path = [];
  final Set<int> _used = {};
  Size _size = Size.zero;
  bool _sent = false;

  IqTrace get _trace => widget.trace;

  bool get _stuck {
    if (_path.isEmpty || _used.length == _trace.edges.length) return false;
    final last = _path.last;
    for (var i = 0; i < _trace.edges.length; i++) {
      final (a, b) = _trace.edges[i];
      if (!_used.contains(i) && (a == last || b == last)) return false;
    }
    return true;
  }

  int? _nodeAt(Offset position) {
    for (var i = 0; i < _trace.points.length; i++) {
      if ((_trace.offsetOf(i, _size) - position).distance < 28) return i;
    }
    return null;
  }

  void _visit(Offset position) {
    if (!widget.enabled || _sent) return;
    final node = _nodeAt(position);
    if (node == null) return;
    if (_path.isEmpty) {
      // Points numérotés : on commence forcément par 1.
      if (_trace.ordered && node != 0) return;
      setState(() => _path.add(node));
      return;
    }
    if (node == _path.last) return;
    if (_trace.ordered) {
      final n = _trace.points.length;
      final closed = _trace.edgeBetween(0, n - 1) >= 0;
      final next = _path.length < n ? _path.length : (closed ? 0 : -1);
      if (node != next) return;
    }
    final edge = _trace.edgeBetween(_path.last, node);
    if (edge < 0 || _used.contains(edge)) {
      // Au tout début, toucher un autre point change le départ.
      if (_used.isEmpty && !_trace.ordered) setState(() => _path[0] = node);
      return;
    }
    GameFeedbackScope.of(context).play(Sfx.key);
    setState(() {
      _used.add(edge);
      _path.add(node);
    });
    if (_used.length == _trace.edges.length) {
      _sent = true;
      widget.onDone(_path.join('-'));
    }
  }

  void _reset() => setState(() {
    _path.clear();
    _used.clear();
    _sent = false;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final short = MediaQuery.sizeOf(context).height < 740;
            final width = min(
              constraints.maxWidth,
              short ? 260.0 : 300.0,
            );
            _size = Size(width, _trace.heightFor(width));
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.purpleLight, width: 3),
                ),
                child: RawGestureDetector(
                  key: const Key('iq_trace_board'),
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    _EagerPanGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _EagerPanGestureRecognizer
                        >(
                      () => _EagerPanGestureRecognizer(),
                      (instance) {
                        instance.onStart = (d) {
                          _visit(d.localPosition);
                        };
                        instance.onUpdate = (d) {
                          _visit(d.localPosition);
                        };
                      },
                    ),
                  },
                  child: SizedBox.fromSize(
                    size: _size,
                    child: CustomPaint(
                      painter: _TracePainter(
                        trace: _trace,
                        path: List.of(_path),
                        start: widget.start,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        if (_stuck)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.iqTraceStuck,
              key: const Key('iq_trace_stuck'),
              textAlign: TextAlign.center,
              style: gameFont(size: 16, color: AppColors.yellow),
            ),
          ),
        CandyButton(
          key: const Key('iq_trace_reset'),
          label: l10n.iqTraceRestart,
          icon: Icons.replay_rounded,
          color: _stuck ? AppColors.yellow : AppColors.white,
          height: MediaQuery.sizeOf(context).height < 740 ? 38 : 42,
          fontSize: 14,
          onPressed: _path.isEmpty || !widget.enabled ? null : _reset,
        ),
      ],
    );
  }
}
