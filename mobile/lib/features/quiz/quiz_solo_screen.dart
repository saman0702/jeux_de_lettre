import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/round_view.dart';
import '../iq/iq_widgets.dart';
import '../online/online_controller.dart';
import '../online/widgets/online_header.dart';
import '../perks/perks_controller.dart';
import '../wallet/wallet.dart';
import 'quiz_models.dart';
import 'quiz_recent.dart';

/// Partie solo d'un module quiz (Chrono, Mot & Sens…).
class QuizSoloScreen extends StatefulWidget {
  const QuizSoloScreen({
    super.key,
    required this.title,
    required this.theme,
    required this.accent,
    required this.questions,
    required this.game,
    this.rounds = 5,
    this.secondsPerQuestion = 15,
    this.apiClient,
  });

  final String title;
  final BackgroundTheme theme;
  final Color accent;
  final List<QuizQuestion> questions;

  /// `chrono` ou `mots` (crédits pièces côté serveur).
  final String game;
  final int rounds;

  /// Secondes par question ; 0 = illimité.
  final int secondsPerQuestion;
  final ApiClient? apiClient;

  @override
  State<QuizSoloScreen> createState() => _QuizSoloScreenState();
}

class _QuizSoloScreenState extends State<QuizSoloScreen> {
  List<QuizQuestion> _deck = const [];
  final List<QuizTurn> _turns = [];
  int _index = 0;
  bool _revealed = false;
  bool _done = false;
  bool _ready = false;
  int _coinsWon = 0;
  bool _claiming = false;
  Timer? _ticker;
  late DateTime _deadline;
  Duration _remaining = Duration.zero;

  bool get _timed => widget.secondsPerQuestion > 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareDeck());
  }

  /// Jamais vues d'abord, puis les plus anciennes (même en ligne).
  Future<void> _prepareDeck() async {
    final recent = await QuizRecentStore.load(widget.game);
    final picked = QuizRecentStore.pickDeck(
      questions: widget.questions,
      recentOldestFirst: recent,
      rounds: widget.rounds,
      random: Random(),
    );
    if (!mounted) return;
    setState(() {
      _deck = picked;
      _ready = true;
    });
    _armTimer();
  }

  void _rememberCurrent() {
    unawaited(QuizRecentStore.remember(widget.game, [_current.id]));
  }

  PerksController? _perks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _perks ??= PerksScope.maybeOf(context);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_done) unawaited(_perks?.onGameFinished() ?? Future.value());
    super.dispose();
  }

  QuizQuestion get _current => _deck[_index];

  void _armTimer() {
    _ticker?.cancel();
    if (!_timed) {
      _remaining = Duration.zero;
      return;
    }
    _deadline = DateTime.now().add(
      Duration(seconds: widget.secondsPerQuestion),
    );
    _remaining = Duration(seconds: widget.secondsPerQuestion);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _revealed || _done) return;
      final left = _deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        _ticker?.cancel();
        _onTimeout();
        return;
      }
      setState(() => _remaining = left);
    });
  }

  void _onTimeout() {
    if (_revealed || _done) return;
    final feedback = GameFeedbackScope.of(context);
    feedback.play(Sfx.invalid);
    feedback.haptic(Haptic.medium);
    setState(() {
      _revealed = true;
      _remaining = Duration.zero;
      _turns.add(
        QuizTurn(
          question: _current,
          choice: null,
          correct: false,
          points: 0,
        ),
      );
    });
    _rememberCurrent();
  }

  void _pick(int i) {
    if (_revealed || _done) return;
    _ticker?.cancel();
    final q = _current;
    final ok = q.isCorrect(i);
    final feedback = GameFeedbackScope.of(context);
    feedback.play(ok ? Sfx.valid : Sfx.invalid);
    feedback.haptic(ok ? Haptic.light : Haptic.medium);
    setState(() {
      _revealed = true;
      _turns.add(
        QuizTurn(
          question: q,
          choice: i,
          correct: ok,
          points: ok ? 10 : 0,
        ),
      );
    });
    _rememberCurrent();
  }

  void _next() {
    if (_index + 1 >= _deck.length) {
      GameFeedbackScope.of(context).play(Sfx.victory);
      setState(() => _done = true);
      unawaited(_claimRewards());
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
    _armTimer();
  }

  /// En ligne : le serveur vérifie les réponses et convertit les points en pièces.
  Future<void> _claimRewards() async {
    if (_claiming || _coinsWon > 0) return;
    _claiming = true;
    final online = OnlineScope.of(context);
    if (!online.isOnline) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final api = widget.apiClient ?? ApiClient();
      final body = await api.postJson('/api/v1/quiz/solo/finish', {
        'client_id': online.clientId,
        'game': widget.game,
        'answers': [
          for (final t in _turns)
            {'id': t.question.id, 'choice': t.choice},
        ],
      });
      if (!mounted) return;
      if (body['wallet'] case final Map<String, dynamic> wallet) {
        final snap = WalletSnapshot.fromJson(wallet);
        online.applyWallet(snap);
        setState(() => _coinsWon = snap.coinsGained);
      } else {
        setState(() {});
      }
    } on Object catch (e) {
      debugPrint('quiz reward: $e');
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      body: GameBackground(
        theme: widget.theme,
        palette: BackgroundPalette.history,
        child: SafeArea(
          child: Column(
            children: [
              OnlineHeader(
                title: widget.title,
                quitStyle: !_done,
                onBack: () => Navigator.of(context).pop(),
                trailing: !_done && _timed && !_revealed
                    ? TimerBadge(
                        key: const Key('quiz_timer'),
                        remaining: _remaining,
                        total: Duration(seconds: widget.secondsPerQuestion),
                        size: 52,
                      )
                    : null,
              ),
              Expanded(
                child: !_ready
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                        ),
                      )
                    : _done
                    ? _result(l10n)
                    : IqScrollArea(
                        children: [
                          Text(
                            l10n.roundProgress(_index + 1, _deck.length),
                            textAlign: TextAlign.center,
                            style: fredoka(
                              size: 14,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GameCard(
                            color: AppColors.parchment,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _current.promptIn(language),
                              key: const Key('quiz_prompt'),
                              textAlign: TextAlign.center,
                              style: gameFont(
                                size: 18,
                                color: AppColors.inkRetro,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_revealed)
                            _choicesGrid(language)
                          else ...[
                            GameCard(
                              color: AppColors.parchment,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Text(
                                    l10n.iqGoodAnswer.toUpperCase(),
                                    style: gameFont(
                                      size: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                  Text(
                                    _current.answerText(language),
                                    key: const Key('quiz_answer'),
                                    style: gameFont(
                                      size: 22,
                                      color: AppColors.sage,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const GameIcon(
                                        GameIconKind.hint,
                                        size: 20,
                                        color: AppColors.ochre,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _current.explanationIn(language),
                                          style: fredoka(
                                            size: 15,
                                            color: AppColors.inkRetro,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                child: CandyButton(
                                  key: const Key('quiz_next'),
                                  label: _index + 1 >= _deck.length
                                      ? l10n.quizSeeScore
                                      : l10n.iqNext,
                                  color: widget.accent,
                                  textColor: AppColors.white,
                                  height: 48,
                                  fontSize: 17,
                                  onPressed: _next,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Grille 2×2 centrée, teintes sable / rétro.
  Widget _choicesGrid(String language) {
    final choices = _current.choicesIn(language);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          children: [
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    Expanded(
                      child: CandyButton(
                        key: Key('quiz_choice_${row * 2 + col}'),
                        label: choices[row * 2 + col],
                        color: AppColors.sandChoices[(row * 2 + col) % 4],
                        textColor: AppColors.inkRetro,
                        fontSize: 15,
                        height: 88,
                        maxLines: 3,
                        onPressed: () => _pick(row * 2 + col),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _result(AppLocalizations l10n) {
    final language = Localizations.localeOf(context).languageCode;
    final score = _turns.fold<int>(0, (s, t) => s + t.points);
    final correct = _turns.where((t) => t.correct).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                GameCard(
                  color: AppColors.parchment,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        l10n.gameOver,
                        style: fredoka(size: 22, color: AppColors.inkRetro),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$correct / ${_deck.length}',
                        key: const Key('quiz_score'),
                        style: gameFont(size: 40, color: widget.accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.iqResultScore(correct, _deck.length, score),
                        textAlign: TextAlign.center,
                        style: fredoka(
                          size: 17,
                          weight: FontWeight.w600,
                          color: AppColors.inkRetro,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.pointsShort(score),
                        style: gameFont(size: 22, color: widget.accent),
                      ),
                      if (_claiming && _coinsWon == 0) ...[
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ],
                      if (_coinsWon > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const GameIcon(GameIconKind.coin, size: 26),
                            const SizedBox(width: 8),
                            Text(
                              l10n.iqCoinsWon(_coinsWon),
                              key: const Key('quiz_coins_won'),
                              style: gameFont(
                                size: 20,
                                color: AppColors.ochre,
                              ),
                            ),
                          ],
                        ),
                      ] else if (!_claiming &&
                          !OnlineScope.of(context).isOnline) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.iqOfflineNoCoins,
                          textAlign: TextAlign.center,
                          style: fredoka(size: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.yourAnswers,
                  style: gameFont(size: 18, color: AppColors.white),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _turns.length; i++)
                  _summaryRow(l10n, language, i, _turns[i]),
              ],
            ),
          ),
          CandyButton(
            key: const Key('quiz_replay'),
            label: l10n.playAgain,
            icon: Icons.replay_rounded,
            color: widget.accent,
            textColor: AppColors.white,
            height: 48,
            fontSize: 17,
            onPressed: _replay,
          ),
          const SizedBox(height: 10),
          CandyButton(
            key: const Key('quiz_home'),
            label: l10n.quit.toUpperCase(),
            color: AppColors.white,
            textColor: AppColors.inkRetro,
            height: 48,
            fontSize: 17,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _replay() {
    _ticker?.cancel();
    setState(() {
      _turns.clear();
      _index = 0;
      _revealed = false;
      _done = false;
      _ready = false;
      _coinsWon = 0;
      _claiming = false;
      _deck = const [];
      _remaining = Duration.zero;
    });
    unawaited(_prepareDeck());
  }

  Widget _summaryRow(
    AppLocalizations l10n,
    String language,
    int index,
    QuizTurn turn,
  ) {
    final q = turn.question;
    final ok = turn.correct;
    final yours = turn.choice == null
        ? l10n.iqLate
        : q.choicesIn(language)[turn.choice!];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameCard(
        color: AppColors.parchment,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: ok ? AppColors.sage : AppColors.clay,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${q.promptIn(language)}',
                    style: fredoka(
                      size: 15,
                      weight: FontWeight.w600,
                      color: AppColors.inkRetro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ok
                        ? yours
                        : '$yours → ${q.answerText(language)}',
                    style: fredoka(
                      size: 14,
                      color: ok ? AppColors.sage : AppColors.clay,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
