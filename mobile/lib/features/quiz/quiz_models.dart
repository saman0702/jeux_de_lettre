/// Question à choix multiples pour les modules éducatifs (Chrono, Mot & Sens).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.level,
    required this.prompt,
    required this.choices,
    required this.answer,
    required this.explanation,
  });

  final String id;
  final String kind;
  final int level;
  final Map<String, String> prompt;
  final Map<String, List<String>> choices;
  final int answer;
  final Map<String, String> explanation;

  String promptIn(String language) => prompt[language] ?? prompt['fr'] ?? '';
  String explanationIn(String language) =>
      explanation[language] ?? explanation['fr'] ?? '';
  List<String> choicesIn(String language) =>
      choices[language] ?? choices['fr'] ?? const [];

  bool isCorrect(int? index) => index == answer;

  String answerText(String language) {
    final list = choicesIn(language);
    return answer >= 0 && answer < list.length ? list[answer] : '';
  }
}

class QuizTurn {
  const QuizTurn({
    required this.question,
    required this.choice,
    required this.correct,
    required this.points,
  });

  final QuizQuestion question;
  final int? choice;
  final bool correct;
  final int points;
}
