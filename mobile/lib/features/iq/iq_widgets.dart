import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../core/widgets/outlined_text.dart';
import '../../l10n/app_localizations.dart';
import 'iq_figures.dart';
import 'iq_models.dart';
import 'iq_trace.dart';

const _choiceColors = [
  AppColors.cyan,
  AppColors.pink,
  AppColors.yellow,
  AppColors.green,
];

String iqKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'sequence' => l10n.iqKindSequence,
  'grid' => l10n.iqKindGrid,
  'problem' => l10n.iqKindProblem,
  'letters' => l10n.iqKindLetters,
  'calendar' => l10n.iqKindCalendar,
  'analogy' => l10n.iqKindAnalogy,
  'odd' => l10n.iqKindOdd,
  'matrix' => l10n.iqKindMatrix,
  'rotation' => l10n.iqKindRotation,
  'figure_odd' => l10n.iqKindFigureOdd,
  'trace' => l10n.iqKindTrace,
  _ => l10n.iqKindLogic,
};

/// L'énigme : type, énoncé, suite en tuiles ou grille 3 × 3.
class IqPuzzleCard extends StatelessWidget {
  const IqPuzzleCard({super.key, required this.puzzle, required this.language});

  final IqPuzzle puzzle;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GameCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  iqKindLabel(l10n, puzzle.kind).toUpperCase(),
                  style: gameFont(
                    size: 12,
                    color: AppColors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              for (var i = 0; i < 3; i++)
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: i < puzzle.level
                      ? AppColors.orange
                      : const Color(0xFFDCD3F2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            puzzle.promptIn(language),
            key: const Key('iq_prompt'),
            textAlign: TextAlign.center,
            style: gameFont(size: 18, color: AppColors.ink),
          ),
          if (puzzle.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final item in puzzle.items) _Tile(item)],
            ),
          ],
          if (puzzle.figures != null && puzzle.figures!.layout != 'none') ...[
            const SizedBox(height: 10),
            IqFigureBoard(puzzle.figures!),
          ],
          if (puzzle.grid != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  for (final row in puzzle.grid!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final cell in row)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: _Tile(cell, size: 58),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.text, {this.size = 44});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hidden = text == '?';
    final color = hidden ? AppColors.yellow : AppColors.cloud;
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hidden ? AppColors.orange : const Color(0xFFDCD3F2),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(color),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Taille de son texte (pas toute la ligne), centré dans la tuile.
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: gameFont(size: size * 0.42, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Zone de réponse : 4 grands choix, ou clavier de nombres.
class IqAnswerPad extends StatefulWidget {
  const IqAnswerPad({
    super.key,
    required this.puzzle,
    required this.language,
    required this.onAnswer,
    this.enabled = true,
    this.removed = const {},
    this.traceStart,
  });

  final IqPuzzle puzzle;
  final String language;
  final ValueChanged<String> onAnswer;
  final bool enabled;

  /// Indice d'un tracé : le point de départ.
  final int? traceStart;

  /// Choix retirés par le joker 50/50.
  final Set<int> removed;

  @override
  State<IqAnswerPad> createState() => _IqAnswerPadState();
}

class _IqAnswerPadState extends State<IqAnswerPad> {
  String _typed = '';

  void _key(String key) {
    GameFeedbackScope.of(context).play(Sfx.key);
    setState(() {
      if (key == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (key == '−') {
        _typed = _typed.startsWith('-') ? _typed.substring(1) : '-$_typed';
      } else if (_typed.replaceAll('-', '').length < 7) {
        _typed += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final puzzle = widget.puzzle;
    final trace = puzzle.trace;
    if (trace != null) {
      return IqTraceBoard(
        trace: trace,
        onDone: widget.onAnswer,
        enabled: widget.enabled,
        start: widget.traceStart,
      );
    }
    final figures = puzzle.figures;
    if (figures != null) {
      return IqFigureChoices(
        figures: figures,
        onAnswer: widget.onAnswer,
        enabled: widget.enabled,
        removed: widget.removed,
      );
    }
    if (!puzzle.typed) {
      final choices = puzzle.choicesIn(widget.language);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, choice) in choices.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: widget.removed.contains(i) ? 0.3 : 1,
                child: CandyButton(
                  key: Key('iq_choice_$i'),
                  label: choice,
                  color: _choiceColors[i % _choiceColors.length],
                  height: 48,
                  fontSize: 16,
                  onPressed: widget.enabled && !widget.removed.contains(i)
                      ? () => widget.onAnswer('$i')
                      : null,
                ),
              ),
            ),
        ],
      );
    }
    Widget key(
      String label, {
      Color color = AppColors.white,
      int flex = 1,
    }) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CandyButton(
          key: Key('iq_key_$label'),
          // Effacer : une icône (le symbole ⌫ manque dans la police du jeu).
          label: label == '⌫' ? '' : label,
          icon: label == '⌫' ? Icons.backspace_rounded : null,
          color: color,
          height: 40,
          fontSize: 20,
          onPressed: widget.enabled ? () => _key(label) : null,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('iq_typed'),
          height: 42,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.yellow, width: 3),
          ),
          child: Text(
            _typed.isEmpty ? l10n.iqTypeAnswer : _typed,
            style: gameFont(
              size: _typed.isEmpty ? 16 : 28,
              color: _typed.isEmpty ? AppColors.inkSoft : AppColors.ink,
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k)]),
        Row(
          children: [
            key('−'),
            key('0'),
            key('⌫', color: AppColors.cloud),
          ],
        ),
        const SizedBox(height: 6),
        CandyButton(
          key: const Key('iq_submit'),
          label: l10n.iqValidate,
          icon: Icons.check_rounded,
          color: AppColors.green,
          textColor: AppColors.white,
          height: 48,
          fontSize: 20,
          onPressed: widget.enabled && _typed.replaceAll('-', '').isNotEmpty
              ? () => widget.onAnswer(_typed)
              : null,
        ),
      ],
    );
  }
}

/// Ligne d'un joueur dans les résultats d'une énigme.
class IqPlayerResult {
  const IqPlayerResult({
    required this.name,
    required this.answer,
    required this.correct,
    required this.points,
    this.isMe = false,
    this.shownAnswer,
  });

  final String name;
  final String? answer;

  /// Réponse déjà mise en forme (relais : lue sur l'énigme de ce joueur).
  final String? shownAnswer;
  final bool correct;
  final int points;
  final bool isMe;
}

/// Après l'énigme : la bonne réponse, l'explication, la réponse de chacun.
class IqRevealCard extends StatelessWidget {
  const IqRevealCard({
    super.key,
    required this.puzzle,
    required this.language,
    required this.players,
  });

  final IqPuzzle puzzle;
  final String language;
  final List<IqPlayerResult> players;

  String _shown(String? answer) => puzzle.shown(answer, language);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.iqGoodAnswer.toUpperCase(),
                textAlign: TextAlign.center,
                style: gameFont(
                  size: 13,
                  color: AppColors.inkSoft,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                puzzle.answerText(language),
                key: const Key('iq_answer'),
                textAlign: TextAlign.center,
                style: gameFont(size: 28, color: AppColors.green),
              ),
              // Un seul trait : une solution, dessinée.
              if (puzzle.trace != null && puzzle.answer != null)
                IqTraceView(
                  trace: puzzle.trace!,
                  path: [
                    for (final n in puzzle.answer!.split('-')) int.parse(n),
                  ],
                ),
              // Schémas : la bonne figure, dessinée.
              if (puzzle.figures != null && puzzle.answer != null)
                Center(
                  child: IqFigureView(
                    puzzle.figures!.options[int.parse(puzzle.answer!)],
                    size: 72,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GameIcon(
                    GameIconKind.hint,
                    size: 22,
                    color: AppColors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      puzzle.explanationIn(language),
                      style: fredoka(size: 15, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GameCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final p in players)
                Container(
                  color: p.isMe
                      ? AppColors.yellow.withValues(alpha: 0.25)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        p.correct
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: p.correct ? AppColors.green : AppColors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.isMe ? l10n.youBadge : p.name,
                          style: fredoka(size: 16, weight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        p.shownAnswer ?? _shown(p.answer),
                        style: fredoka(size: 15, color: AppColors.inkSoft),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 46,
                        child: Text(
                          p.points > 0 ? '+${p.points}' : '${p.points}',
                          textAlign: TextAlign.end,
                          style: gameFont(
                            size: 17,
                            color: p.points > 0
                                ? AppColors.green
                                : (p.points < 0
                                      ? AppColors.red
                                      : AppColors.inkSoft),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// En-tête d'une énigme : numéro, temps restant.
class IqHeader extends StatelessWidget {
  const IqHeader({
    super.key,
    required this.number,
    required this.total,
    this.trailing,
  });

  final int number;
  final int total;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedText(
            l10n.iqQuestion(number, total),
            style: gameFont(size: 22, color: AppColors.white),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Jokers payants de l'énigme en cours : 50/50 (choix) ou indice (nombre),
/// +15 s, passer.
class IqJokerBar extends StatelessWidget {
  const IqJokerBar({
    super.key,
    required this.puzzle,
    required this.prices,
    required this.used,
    required this.onUse,
    this.busy = false,
  });

  final IqPuzzle puzzle;
  final Map<String, int> prices;
  final Set<String> used;
  final ValueChanged<String> onUse;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kinds = [
      puzzle.input == 'choice' ? 'fifty' : 'hint',
      'time',
      'skip',
    ].where(prices.containsKey).toList();
    String label(String kind) => switch (kind) {
      'fifty' => l10n.iqJokerFifty,
      'hint' => l10n.iqJokerHint,
      'time' => l10n.iqJokerTime,
      _ => l10n.iqJokerSkip,
    };
    return Row(
      children: [
        for (final (i, kind) in kinds.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: CandyButton(
              key: Key('iq_joker_$kind'),
              label: label(kind),
              badge: '${prices[kind]}',
              gameIcon: GameIconKind.coin,
              color: AppColors.white,
              height: 40,
              fontSize: 14,
              onPressed: busy || used.contains(kind) ? null : () => onUse(kind),
            ),
          ),
        ],
      ],
    );
  }
}
