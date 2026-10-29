import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../l10n/app_localizations.dart';

/// Figure à tracer d'un seul trait : des points (sur une petite grille) et
/// des lignes entre eux.
class IqTrace {
  const IqTrace({required this.points, required this.edges});

  factory IqTrace.fromJson(Map<String, dynamic> json) => IqTrace(
    points: [
      for (final p in json['points'] as List)
        ((p as List)[0] as int, p[1] as int),
    ],
    edges: [
      for (final e in json['edges'] as List)
        ((e as List)[0] as int, e[1] as int),
    ],
  );

  final List<(int, int)> points;
  final List<(int, int)> edges;

  /// Ligne entre [a] et [b], ou -1.
  int edgeBetween(int a, int b) => edges.indexWhere(
    (e) => (e.$1 == a && e.$2 == b) || (e.$1 == b && e.$2 == a),
  );

  /// Même règle que le serveur : chaque ligne une seule fois, sans saut.
  bool isValid(String raw) {
    final path = raw.split('-').map(int.tryParse).toList();
    if (path.contains(null) || path.length != edges.length + 1) return false;
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
    for (var i = 0; i < trace.points.length; i++) {
      final c = trace.offsetOf(i, size);
      final hinted = start == i && path.isEmpty;
      canvas.drawCircle(
        c,
        i == current || hinted ? 13 : 10,
        Paint()
          ..color = i == current
              ? AppColors.yellow
              : (hinted ? AppColors.orange : AppColors.white),
      );
      canvas.drawCircle(
        c,
        i == current || hinted ? 13 : 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.purpleDeep,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.path.length != path.length || old.start != start;
}

/// La figure dessinée (correction : la solution en vert).
class IqTraceView extends StatelessWidget {
  const IqTraceView({super.key, required this.trace, this.path = const []});

  final IqTrace trace;
  final List<int> path;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = min(constraints.maxWidth, 260.0);
      return Center(
        child: SizedBox(
          width: width,
          height: trace.heightFor(width),
          child: CustomPaint(
            painter: _TracePainter(trace: trace, path: path, solved: true),
          ),
        ),
      );
    },
  );
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
    if (!widget.enabled) return;
    final node = _nodeAt(position);
    if (node == null) return;
    if (_path.isEmpty) {
      setState(() => _path.add(node));
      return;
    }
    if (node == _path.last) return;
    final edge = _trace.edgeBetween(_path.last, node);
    if (edge < 0 || _used.contains(edge)) {
      // Au tout début, toucher un autre point change le départ.
      if (_used.isEmpty) setState(() => _path[0] = node);
      return;
    }
    GameFeedbackScope.of(context).play(Sfx.key);
    setState(() {
      _used.add(edge);
      _path.add(node);
    });
    if (_used.length == _trace.edges.length) {
      widget.onDone(_path.join('-'));
    }
  }

  void _reset() => setState(() {
    _path.clear();
    _used.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = min(constraints.maxWidth, 320.0);
            _size = Size(width, _trace.heightFor(width));
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.purpleLight, width: 3),
                ),
                child: GestureDetector(
                  key: const Key('iq_trace_board'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _visit(d.localPosition),
                  onPanUpdate: (d) => _visit(d.localPosition),
                  onTapUp: (d) => _visit(d.localPosition),
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
          height: 42,
          fontSize: 15,
          onPressed: _path.isEmpty || !widget.enabled ? null : _reset,
        ),
      ],
    );
  }
}
