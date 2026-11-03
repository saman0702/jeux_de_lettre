import 'iq_count.dart';
import 'iq_figures.dart';
import 'iq_flow.dart';
import 'iq_trace.dart';

/// Une énigme de QI, telle que le serveur l'envoie (sans la réponse pendant la
/// manche, avec la réponse et l'explication après).
class IqPuzzle {
  const IqPuzzle({
    required this.id,
    required this.kind,
    required this.level,
    required this.input,
    required this.prompt,
    this.choices,
    this.grid,
    this.items = const [],
    this.answer,
    this.explanation = const {},
    this.figures,
    this.trace,
    this.diagram,
    this.flow,
  });

  factory IqPuzzle.fromJson(Map<String, dynamic> json) => IqPuzzle(
    id: json['id'] as String,
    kind: json['kind'] as String,
    level: json['level'] as int? ?? 1,
    input: json['input'] as String? ?? 'choice',
    prompt: _texts(json['prompt']),
    choices: json['choices'] == null
        ? null
        : {
            for (final e in (json['choices'] as Map).entries)
              e.key as String: [for (final c in e.value as List) '$c'],
          },
    grid: json['grid'] == null
        ? null
        : [
            for (final row in json['grid'] as List)
              [for (final cell in row as List) '$cell'],
          ],
    items: [for (final i in (json['items'] as List?) ?? const []) '$i'],
    answer: json['answer'] as String?,
    explanation: _texts(json['explanation']),
    figures: json['figures'] == null
        ? null
        : IqFigures.fromJson(json['figures'] as Map<String, dynamic>),
    trace: json['trace'] == null
        ? null
        : IqTrace.fromJson(json['trace'] as Map<String, dynamic>),
    diagram: json['diagram'] == null
        ? null
        : IqDiagram.fromJson(json['diagram'] as Map<String, dynamic>),
    flow: json['flow'] == null
        ? null
        : IqFlow.fromJson(json['flow'] as Map<String, dynamic>),
  );

  static Map<String, String> _texts(Object? raw) => {
    for (final e in ((raw as Map?) ?? const {}).entries)
      e.key as String: e.value as String,
  };

  final String id;

  /// sequence, grid, problem, letters, calendar, analogy, odd, logic,
  /// matrix, rotation, figure_odd, trace, count, dots, flow.
  final String kind;

  /// 1 facile, 2 moyen, 3 difficile.
  final int level;

  /// « number » | « choice » | « trace » | « flow ».
  final String input;
  final Map<String, String> prompt;
  final Map<String, List<String>>? choices;
  final List<List<String>>? grid;

  /// Suite affichée en grandes tuiles (« ? » pour la case à trouver).
  final List<String> items;

  /// Nombre, ou indice du bon choix ; connu après la manche (ou en solo).
  final String? answer;
  final Map<String, String> explanation;

  /// Énigme à schémas : figures à dessiner, choix notés A à D.
  final IqFigures? figures;

  /// Un seul trait : la figure à tracer ; la réponse est un chemin « 0-3-1… ».
  final IqTrace? trace;

  /// Compter les triangles : segments + surbrillances d'explication.
  final IqDiagram? diagram;

  /// Relier les couleurs (Flow).
  final IqFlow? flow;

  bool get traced => input == 'trace';

  bool get typed => input == 'number';

  bool get flowing => input == 'flow';

  String promptIn(String language) => prompt[language] ?? prompt['fr'] ?? '';
  String explanationIn(String language) =>
      explanation[language] ?? explanation['fr'] ?? '';
  List<String> choicesIn(String language) =>
      choices?[language] ?? choices?['fr'] ?? const [];

  /// La bonne réponse, lisible (le choix lui-même pour un QCM).
  String answerText(String language) {
    final a = answer;
    if (a == null || traced || flowing) return '';
    if (typed) return a;
    final list = choicesIn(language);
    final i = int.tryParse(a) ?? -1;
    return i >= 0 && i < list.length ? list[i] : a;
  }

  /// Une réponse donnée, lisible (le texte du choix pour un QCM).
  String shown(String? raw, String language) {
    if (raw == null || raw.isEmpty) return '—';
    if (traced || flowing) return '';
    if (typed) return raw;
    final list = choicesIn(language);
    final i = int.tryParse(raw) ?? -1;
    return i >= 0 && i < list.length ? list[i] : raw;
  }

  /// Même règle que le serveur : « 1 024 » et « 1024,0 » valent 1024.
  bool isCorrect(String? raw) {
    final a = answer;
    if (a == null || raw == null) return false;
    if (flowing) return flow?.isValid(raw) ?? false;
    final text = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (text.isEmpty) return false;
    if (traced) return trace?.isValid(text) ?? false;
    if (!typed) return text == a;
    final value = double.tryParse(text);
    return value != null && value == double.tryParse(a);
  }
}

/// Rapidité d'une réponse (temps absolu, pas le plafond du chrono).
enum IqSpeed { fast, medium, slow }

/// Temps de référence (secondes) par niveau — aligné sur le serveur.
const iqExpectedSeconds = {1: 25.0, 2: 40.0, 3: 55.0};

IqSpeed iqSpeedOf(Duration elapsed, int level) {
  final expected = iqExpectedSeconds[level] ?? 40.0;
  final seconds = elapsed.inMilliseconds / 1000.0;
  if (seconds <= expected * 0.55) return IqSpeed.fast;
  if (seconds <= expected * 1.25) return IqSpeed.medium;
  return IqSpeed.slow;
}

double iqSpeedFactor(bool correct, IqSpeed? speed) {
  if (!correct) return 0;
  return switch (speed) {
    IqSpeed.fast => 1.05,
    IqSpeed.slow => 0.65,
    _ => 1.0,
  };
}

/// Affiche « 12 s » ou « 1:05 ».
String iqFormatElapsed(Duration elapsed) {
  final total = elapsed.inSeconds.clamp(0, 99 * 60);
  if (total < 60) return '${total}s';
  final m = total ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Réglages des points du QI (choisis par l'hôte, ou en solo).
class IqScoring {
  const IqScoring({this.speedBonus = true, this.penalty = false});

  final bool speedBonus;
  final bool penalty;

  static const correct = 10;
  static const speedMax = 10;
  static const wrong = 5;

  int points({
    required bool correct,
    required bool answered,
    required Duration elapsed,
    required Duration duration,
    int level = 2,
  }) {
    if (correct) {
      var bonus = 0;
      if (speedBonus) {
        final secs = duration.inSeconds;
        if (secs > 0 && secs < 300) {
          final left = 1 - elapsed.inMilliseconds / duration.inMilliseconds;
          bonus = (speedMax * left.clamp(0.0, 1.0)).round();
        } else {
          // ≥ 5 min ou illimité : jugement absolu.
          bonus = switch (iqSpeedOf(elapsed, level)) {
            IqSpeed.fast => 8,
            IqSpeed.medium => 4,
            IqSpeed.slow => 0,
          };
        }
      }
      return IqScoring.correct + bonus;
    }
    return penalty && answered ? -wrong : 0;
  }
}

/// QI estimé : 70–128, rapidité comprise. Même calcul que le serveur.
int iqEstimate(List<(int level, bool correct, IqSpeed? speed)> results) {
  if (results.isEmpty) return 100;
  const weight = {1: 1.0, 2: 1.5, 3: 2.0};
  const average = 0.65;
  const iqMin = 70;
  const iqMax = 128;
  final total = results.fold(0.0, (s, r) => s + weight[r.$1]!);
  final got = results.fold(
    0.0,
    (s, r) => s + weight[r.$1]! * iqSpeedFactor(r.$2, r.$3),
  );
  final success = (got / total).clamp(0.0, 1.0);
  if (success <= average) {
    return (iqMin + (100 - iqMin) * success / average).round();
  }
  return (100 + (iqMax - 100) * (success - average) / (1 - average)).round();
}
