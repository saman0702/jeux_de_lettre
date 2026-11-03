import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/data/models.dart';
import 'iq_count.dart';
import 'iq_figures.dart';
import 'iq_flow.dart';
import 'iq_models.dart';
import 'iq_run.dart';
import 'iq_trace.dart';

/// Brouillon d'une partie solo QI : pause après une manche, reprise plus tard.
class IqSoloDraft {
  const IqSoloDraft({
    required this.online,
    required this.rounds,
    required this.duration,
    required this.difficulty,
    required this.scoring,
    required this.nextIndex,
    required this.finished,
    required this.turns,
    this.sessionId,
    this.puzzles = const [],
    this.coinsWon = 0,
    this.iq,
  });

  final bool online;
  final String? sessionId;
  final int rounds;
  final int duration;
  final Difficulty difficulty;
  final IqScoring scoring;

  /// Index 0-based de la prochaine énigme à jouer (ou [puzzles.length] si fini).
  final int nextIndex;
  final bool finished;

  /// Énigmes restantes / toutes (hors ligne seulement).
  final List<IqPuzzle> puzzles;
  final List<IqTurn> turns;
  final int coinsWon;
  final int? iq;

  int get answeredCount => turns.length;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'online': online,
    'session_id': sessionId,
    'rounds': rounds,
    'duration': duration,
    'difficulty': difficulty.name,
    'speed_bonus': scoring.speedBonus,
    'penalty': scoring.penalty,
    'next_index': nextIndex,
    'finished': finished,
    'coins_won': coinsWon,
    'iq': iq,
    'puzzles': [for (final p in puzzles) iqPuzzleToJson(p)],
    'turns': [for (final t in turns) _turnToJson(t)],
  };

  factory IqSoloDraft.fromJson(Map<String, dynamic> json) {
    final difficultyName = json['difficulty'] as String? ?? 'normal';
    return IqSoloDraft(
      online: json['online'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
      rounds: json['rounds'] as int? ?? 10,
      duration: json['duration'] as int? ?? 0,
      difficulty: Difficulty.values.firstWhere(
        (d) => d.name == difficultyName,
        orElse: () => Difficulty.normal,
      ),
      scoring: IqScoring(
        speedBonus: json['speed_bonus'] as bool? ?? true,
        penalty: json['penalty'] as bool? ?? false,
      ),
      nextIndex: json['next_index'] as int? ?? 0,
      finished: json['finished'] as bool? ?? false,
      coinsWon: json['coins_won'] as int? ?? 0,
      iq: json['iq'] as int?,
      puzzles: [
        for (final p in (json['puzzles'] as List?) ?? const [])
          IqPuzzle.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
      turns: [
        for (final t in (json['turns'] as List?) ?? const [])
          _turnFromJson(Map<String, dynamic>.from(t as Map)),
      ],
    );
  }
}

/// Sauvegarde locale du solo en pause (une seule à la fois).
class IqSoloDraftStore {
  IqSoloDraftStore._();

  static const _key = 'iq.solo_draft';

  static Future<IqSoloDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      return IqSoloDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(IqSoloDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(draft.toJson()));
    } catch (_) {
      // Hors environnement prefs (ex. certains tests) : pas de reprise.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

Map<String, dynamic> iqPuzzleToJson(IqPuzzle p) => {
  'id': p.id,
  'kind': p.kind,
  'level': p.level,
  'input': p.input,
  'prompt': p.prompt,
  if (p.choices != null) 'choices': p.choices,
  if (p.grid != null) 'grid': p.grid,
  'items': p.items,
  if (p.answer != null) 'answer': p.answer,
  'explanation': p.explanation,
  if (p.figures != null) 'figures': _figuresToJson(p.figures!),
  if (p.trace != null) 'trace': _traceToJson(p.trace!),
  if (p.diagram != null) 'diagram': p.diagram!.toJson(),
  if (p.flow != null) 'flow': p.flow!.toJson(),
};

Map<String, dynamic> _figuresToJson(IqFigures f) => {
  'layout': f.layout,
  'cells': [
    for (final c in f.cells) c == null ? null : _figureToJson(c),
  ],
  'options': [for (final o in f.options) _figureToJson(o)],
};

Map<String, dynamic> _figureToJson(IqFigure f) => {
  's': f.shape,
  'c': f.color,
  'n': f.count,
  'f': f.filled,
  'r': f.rotation,
};

Map<String, dynamic> _traceToJson(IqTrace t) => {
  'points': [
    for (final p in t.points) [p.$1, p.$2],
  ],
  'edges': [
    for (final e in t.edges) [e.$1, e.$2],
  ],
  if (t.numbered) 'numbered': true,
  if (t.ordered) 'ordered': true,
};

Map<String, dynamic> _turnToJson(IqTurn t) => {
  'puzzle': iqPuzzleToJson(t.puzzle),
  'answer': t.answer,
  'correct': t.correct,
  'points': t.points,
  'late': t.late,
  'elapsed_ms': t.elapsed.inMilliseconds,
  'speed': t.speed?.name,
  'iq': t.iq,
};

IqTurn _turnFromJson(Map<String, dynamic> json) {
  final speedRaw = json['speed'] as String?;
  return IqTurn(
    puzzle: IqPuzzle.fromJson(
      Map<String, dynamic>.from(json['puzzle'] as Map),
    ),
    answer: json['answer'] as String?,
    correct: json['correct'] as bool? ?? false,
    points: json['points'] as int? ?? 0,
    late: json['late'] as bool? ?? false,
    elapsed: Duration(milliseconds: json['elapsed_ms'] as int? ?? 0),
    speed: speedRaw == null ? null : IqSpeed.values.byName(speedRaw),
    iq: json['iq'] as int?,
  );
}
