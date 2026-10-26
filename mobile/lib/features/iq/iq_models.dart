import 'iq_figures.dart';
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
  );

  static Map<String, String> _texts(Object? raw) => {
    for (final e in ((raw as Map?) ?? const {}).entries)
      e.key as String: e.value as String,
  };

  final String id;

  /// sequence, grid, problem, letters, calendar, analogy, odd, logic,
  /// matrix, rotation, figure_odd (schémas).
  final String kind;

  /// 1 facile, 2 moyen, 3 difficile.
  final int level;

  /// « number » : réponse à taper ; « choice » : 4 choix.
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

  bool get traced => input == 'trace';

  bool get typed => input == 'number';

  String promptIn(String language) => prompt[language] ?? prompt['fr'] ?? '';
  String explanationIn(String language) =>
      explanation[language] ?? explanation['fr'] ?? '';
  List<String> choicesIn(String language) =>
      choices?[language] ?? choices?['fr'] ?? const [];

  /// La bonne réponse, lisible (le choix lui-même pour un QCM).
  String answerText(String language) {
    final a = answer;
    if (a == null || traced) return '';
    if (typed) return a;
    final list = choicesIn(language);
    final i = int.tryParse(a) ?? -1;
    return i >= 0 && i < list.length ? list[i] : a;
  }

  /// Une réponse donnée, lisible (le texte du choix pour un QCM).
  String shown(String? raw, String language) {
    if (raw == null || raw.isEmpty) return '—';
    if (traced) return '';
    if (typed) return raw;
    final list = choicesIn(language);
    final i = int.tryParse(raw) ?? -1;
    return i >= 0 && i < list.length ? list[i] : raw;
  }

  /// Même règle que le serveur : « 1 024 » et « 1024,0 » valent 1024.
  bool isCorrect(String? raw) {
    final a = answer;
    if (a == null || raw == null) return false;
    final text = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (text.isEmpty) return false;
    if (traced) return trace?.isValid(text) ?? false;
    if (!typed) return text == a;
    final value = double.tryParse(text);
    return value != null && value == double.tryParse(a);
  }
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
  }) {
    if (correct) {
      var bonus = 0;
      if (speedBonus && duration.inMilliseconds > 0) {
        final left = 1 - elapsed.inMilliseconds / duration.inMilliseconds;
        bonus = (speedMax * left.clamp(0.0, 1.0)).round();
      }
      return IqScoring.correct + bonus;
    }
    return penalty && answered ? -wrong : 0;
  }
}

/// QI estimé, pour s'amuser : 70 à 145 selon les bonnes réponses, les plus
/// difficiles comptant davantage. 100 = la réussite d'un joueur moyen (60 %).
/// Même calcul que le serveur.
int iqEstimate(List<(int level, bool correct)> results) {
  if (results.isEmpty) return 100;
  const weight = {1: 1.0, 2: 1.5, 3: 2.0};
  const average = 0.6;
  final total = results.fold(0.0, (s, r) => s + weight[r.$1]!);
  final got = results.fold(0.0, (s, r) => r.$2 ? s + weight[r.$1]! : s);
  final success = got / total;
  if (success <= average) return (70 + 30 * success / average).round();
  return (100 + 45 * (success - average) / (1 - average)).round();
}
