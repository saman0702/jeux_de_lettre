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
import 'iq_count.dart';
import 'iq_figures.dart';
import 'iq_flow.dart';
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
  'count' => l10n.iqKindCount,
  'dots' => l10n.iqKindDots,
  'flow' => l10n.iqKindFlow,
  _ => l10n.iqKindLogic,
};

/// Écran court : on compacte polices, tuiles et marges pour éviter un scroll
/// opaque.
bool iqCompactScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 740;

/// Zone d'énigme : défile seulement si besoin, avec un indice visible en bas.
class IqScrollArea extends StatefulWidget {
  const IqScrollArea({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  State<IqScrollArea> createState() => _IqScrollAreaState();
}

class _IqScrollAreaState extends State<IqScrollArea> {
  final _controller = ScrollController();
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(covariant IqScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _controller.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    if (!_controller.hasClients) return;
    final more = _controller.position.maxScrollExtent > 12 &&
        _controller.offset < _controller.position.maxScrollExtent - 8;
    if (more != _more && mounted) setState(() => _more = more);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pad = widget.padding;
    return ClipRect(
      child: Stack(
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _check();
              return false;
            },
            child: ListView(
              controller: _controller,
              // Place pour l'indice : il ne recouvre plus les boutons du bas.
              padding: pad.copyWith(bottom: pad.bottom + (_more ? 28 : 0)),
              children: widget.children,
            ),
          ),
          if (_more)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.purple.withValues(alpha: 0),
                            AppColors.purple.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: AppColors.purple.withValues(alpha: 0.4),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.iqScrollMore,
                            style: fredoka(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// L'énigme : type, énoncé, suite en tuiles ou grille 3 × 3.
class IqPuzzleCard extends StatelessWidget {
  const IqPuzzleCard({
    super.key,
    required this.puzzle,
    required this.language,
    this.summary = false,
  });

  final IqPuzzle puzzle;
  final String language;

  /// Version courte (résultats) : énoncé seul, sans grosse grille.
  final bool summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = iqCompactScreen(context) || summary;
    return GameCard(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        compact ? 8 : 12,
        compact ? 12 : 14,
        compact ? 10 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tile = (constraints.maxWidth.isFinite
                  ? ((constraints.maxWidth - 24) / 3).clamp(36.0, compact ? 48.0 : 56.0)
                  : (compact ? 44.0 : 52.0))
              .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purpleLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      iqKindLabel(l10n, puzzle.kind).toUpperCase(),
                      style: gameFont(
                        size: 11,
                        color: AppColors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  for (var i = 0; i < 3; i++)
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: i < puzzle.level
                          ? AppColors.orange
                          : const Color(0xFFDCD3F2),
                    ),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                puzzle.promptIn(language),
                key: const Key('iq_prompt'),
                textAlign: TextAlign.center,
                style: gameFont(
                  size: compact ? 15 : 17,
                  color: AppColors.ink,
                ),
              ),
              if (!summary && puzzle.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in puzzle.items) _Tile(item, size: tile * 0.85),
                  ],
                ),
              ],
              if (!summary &&
                  puzzle.figures != null &&
                  puzzle.figures!.layout != 'none') ...[
                const SizedBox(height: 8),
                IqFigureBoard(puzzle.figures!, compact: compact),
              ],
              if (!summary && puzzle.grid != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      for (final row in puzzle.grid!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final cell in row)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _Tile(cell, size: tile),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (!summary && puzzle.diagram != null) ...[
                const SizedBox(height: 8),
                IqDiagramView(
                  diagram: puzzle.diagram!,
                  size: compact ? 160 : 200,
                ),
              ],
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hidden ? AppColors.orange : const Color(0xFFDCD3F2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.depthOf(color),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: gameFont(size: size * 0.4, color: AppColors.ink),
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
    final flow = puzzle.flow;
    if (flow != null) {
      return IqFlowBoard(
        flow: flow,
        onDone: widget.onAnswer,
        enabled: widget.enabled,
      );
    }
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
    final compact = iqCompactScreen(context);
    final keyH = compact ? 34.0 : 38.0;
    Widget key(
      String label, {
      Color color = AppColors.white,
      int flex = 1,
    }) => Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(compact ? 2 : 3),
        child: CandyButton(
          key: Key('iq_key_$label'),
          // Effacer : une icône (le symbole ⌫ manque dans la police du jeu).
          label: label == '⌫' ? '' : label,
          icon: label == '⌫' ? Icons.backspace_rounded : null,
          color: color,
          height: keyH,
          fontSize: compact ? 17 : 19,
          onPressed: widget.enabled ? () => _key(label) : null,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('iq_typed'),
          height: compact ? 36 : 40,
          alignment: Alignment.center,
          margin: EdgeInsets.only(bottom: compact ? 4 : 6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.yellow, width: 2.5),
          ),
          child: Text(
            _typed.isEmpty ? l10n.iqTypeAnswer : _typed,
            style: gameFont(
              size: _typed.isEmpty ? 14 : (compact ? 22 : 26),
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
        SizedBox(height: compact ? 4 : 6),
        CandyButton(
          key: const Key('iq_submit'),
          label: l10n.iqValidate,
          icon: Icons.check_rounded,
          color: AppColors.green,
          textColor: AppColors.white,
          height: compact ? 42 : 46,
          fontSize: compact ? 17 : 18,
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
    this.elapsed,
    this.speed,
  });

  final String name;
  final String? answer;

  /// Réponse déjà mise en forme (relais : lue sur l'énigme de ce joueur).
  final String? shownAnswer;
  final bool correct;
  final int points;
  final bool isMe;
  final Duration? elapsed;
  final IqSpeed? speed;
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

  List<int>? _tracePath(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return [for (final n in raw.split('-')) int.parse(n)];
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final answerLabel = puzzle.answerText(language);
    final flowSolution =
        puzzle.flow?.solutions ?? IqFlow.parsePaths(puzzle.answer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.iqGoodAnswer.toUpperCase(),
                textAlign: TextAlign.center,
                style: gameFont(
                  size: 12,
                  color: AppColors.inkSoft,
                  letterSpacing: 1,
                ),
              ),
              if (answerLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  answerLabel,
                  key: const Key('iq_answer'),
                  textAlign: TextAlign.center,
                  style: gameFont(size: 24, color: AppColors.green),
                ),
              ],
              // Un seul trait : solution dessinée progressivement.
              if (puzzle.trace != null && puzzle.answer != null)
                IqTraceView(
                  key: answerLabel.isEmpty ? const Key('iq_answer') : null,
                  trace: puzzle.trace!,
                  path: [
                    for (final n in puzzle.answer!.split('-')) int.parse(n),
                  ],
                  animate: true,
                ),
              // Schémas : la bonne figure, dessinée.
              if (puzzle.figures != null && puzzle.answer != null)
                Center(
                  child: IqFigureView(
                    puzzle.figures!.options[int.parse(puzzle.answer!)],
                    size: 72,
                  ),
                ),
              // Compter : figure avec triangles surlignés.
              if (puzzle.diagram != null) ...[
                const SizedBox(height: 6),
                IqDiagramView(
                  diagram: puzzle.diagram!,
                  showHighlights: true,
                  size: 140,
                ),
              ],
              if (puzzle.flow != null && flowSolution != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: IqFlowView(
                      key: answerLabel.isEmpty
                          ? const Key('iq_answer')
                          : null,
                      flow: puzzle.flow!,
                      paths: flowSolution,
                      animate: true,
                    ),
                  ),
                ),
              ],
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
                Builder(
                  builder: (context) {
                    final playerFlow = puzzle.flowing
                        ? IqFlow.parsePaths(p.answer)
                        : null;
                    final playerTrace = puzzle.traced
                        ? _tracePath(p.answer)
                        : null;
                    final shown = p.shownAnswer ?? _shown(p.answer);
                    return Container(
                      color: p.isMe
                          ? AppColors.yellow.withValues(alpha: 0.25)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                p.correct
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: p.correct
                                    ? AppColors.green
                                    : AppColors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.isMe ? l10n.youBadge : p.name,
                                      style: fredoka(
                                        size: 16,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    if (p.elapsed != null && p.speed != null)
                                      Text(
                                        l10n.iqTimeJudged(
                                          iqFormatElapsed(p.elapsed!),
                                          switch (p.speed!) {
                                            IqSpeed.fast => l10n.iqSpeedFast,
                                            IqSpeed.medium =>
                                              l10n.iqSpeedMedium,
                                            IqSpeed.slow => l10n.iqSpeedSlow,
                                          },
                                        ),
                                        key: p.isMe
                                            ? const Key('iq_time_judged')
                                            : null,
                                        style: fredoka(
                                          size: 13,
                                          color: switch (p.speed!) {
                                            IqSpeed.fast => AppColors.green,
                                            IqSpeed.medium => AppColors.orange,
                                            IqSpeed.slow => AppColors.inkSoft,
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (shown.isNotEmpty)
                                Text(
                                  shown,
                                  style: fredoka(
                                    size: 15,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 46,
                                child: Text(
                                  p.points > 0
                                      ? '+${p.points}'
                                      : '${p.points}',
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
                          if (puzzle.flow != null && playerFlow != null) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: SizedBox(
                                width: 140,
                                child: IqFlowView(
                                  flow: puzzle.flow!,
                                  paths: playerFlow,
                                ),
                              ),
                            ),
                          ],
                          if (puzzle.trace != null && playerTrace != null) ...[
                            const SizedBox(height: 8),
                            IqTraceView(
                              trace: puzzle.trace!,
                              path: playerTrace,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
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
    final compact = iqCompactScreen(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedText(
            l10n.iqQuestion(number, total),
            style: gameFont(
              size: compact ? 18 : 20,
              color: AppColors.white,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Jokers payants de l'énigme en cours : 50/50 (choix) ou indice (nombre),
/// +15 s (sauf temps illimité), passer.
class IqJokerBar extends StatelessWidget {
  const IqJokerBar({
    super.key,
    required this.puzzle,
    required this.prices,
    required this.used,
    required this.onUse,
    this.busy = false,
    this.unlimitedTime = false,
  });

  final IqPuzzle puzzle;
  final Map<String, int> prices;
  final Set<String> used;
  final ValueChanged<String> onUse;
  final bool busy;

  /// Temps illimité : pas de joker +15 s.
  final bool unlimitedTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kinds = [
      puzzle.input == 'choice' ? 'fifty' : 'hint',
      if (!unlimitedTime) 'time',
      if (!unlimitedTime) 'skip',
      if (unlimitedTime) 'reveal',
    ].where(prices.containsKey).toList();
    String label(String kind) => switch (kind) {
      'fifty' => l10n.iqJokerFifty,
      'hint' => l10n.iqJokerHint,
      'time' => l10n.iqJokerTime,
      'reveal' => l10n.iqJokerReveal,
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
              height: iqCompactScreen(context) ? 36 : 40,
              fontSize: 13,
              onPressed: busy || used.contains(kind) ? null : () => onUse(kind),
            ),
          ),
        ],
      ],
    );
  }
}
