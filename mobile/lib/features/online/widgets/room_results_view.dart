import 'dart:async';

import 'package:flutter/material.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/voice/announcements.dart';
import '../../../core/widgets/game_card.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../../game/data/models.dart';
import '../../game/widgets/round_result_view.dart';
import '../data/room_models.dart';
import 'player_avatar.dart';
import '../../../core/widgets/game_icon.dart';

/// Résultats de la manche : tes réponses apparaissent une à une, puis le
/// classement.
class RoomResultsView extends StatefulWidget {
  const RoomResultsView({super.key, required this.room, required this.myId});

  final RoomState room;
  final String myId;

  @override
  State<RoomResultsView> createState() => _RoomResultsViewState();
}

class _RoomResultsViewState extends State<RoomResultsView> {
  static const _stepMs = 380;
  final List<Timer> _timers = [];

  PlayerRoundResult? get _mine {
    for (final p in widget.room.results!.players) {
      if (p.clientId == widget.myId) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playReveal());
  }

  void _playReveal() {
    if (!mounted) return;
    final feedback = GameFeedbackScope.of(context);
    final answers = _mine?.answers ?? const <AnswerResult>[];
    for (final (i, answer) in answers.indexed) {
      _timers.add(
        Timer(Duration(milliseconds: 250 + i * _stepMs), () {
          final valid = answer.status == AnswerStatus.valid;
          feedback.play(valid ? Sfx.valid : Sfx.invalid);
          feedback.haptic(valid ? Haptic.light : Haptic.medium);
        }),
      );
    }
    if ((_mine?.roundScore ?? 0) > 0) {
      _timers.add(
        Timer(
          Duration(milliseconds: 300 + answers.length * _stepMs),
          () => feedback.play(Sfx.points),
        ),
      );
    }
    final players = widget.room.results!.players;
    final line = Announcements(AppLocalizations.of(context)).roomRound(
      roundScores: {for (final p in players) p.clientId: p.roundScore},
      names: {for (final p in players) p.clientId: p.nickname},
      me: widget.myId,
    );
    final language = Localizations.localeOf(context).languageCode;
    _timers.add(
      Timer(
        Duration(milliseconds: 700 + answers.length * _stepMs),
        () => feedback.announce(line, language),
      ),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  /// En ligne : ce que les autres ont trouvé là où le joueur a échoué,
  /// sinon une réponse possible.
  String? _correction(AppLocalizations l10n, AnswerResult answer) {
    if (answer.status == AnswerStatus.valid) return null;
    final results = widget.room.results!;
    final found = results.foundByOthers(answer.category, widget.myId);
    if (found.isNotEmpty) {
      return found
          .take(2)
          .map((f) => l10n.suggestionFoundBy(f.$1, f.$2))
          .join('  ·  ');
    }
    final example = results.examples[answer.category] ?? answer.suggestion;
    return example == null ? null : l10n.suggestionExample(example);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final room = widget.room;
    final results = room.results!;
    final roundScores = {
      for (final p in results.players) p.clientId: p.roundScore,
    };
    final mine = _mine;
    final nextIn = (room.until(room.nextRoundAt).inMilliseconds / 1000).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LetterTile(letter: results.letter, size: 52),
              const SizedBox(width: 14),
              Text(
                l10n.roundProgress(results.number, room.settings.rounds),
                style: fredoka(
                  size: 22,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (mine != null) ...[
                  _SectionTitle(l10n.yourAnswers),
                  for (final (i, answer) in mine.answers.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BounceIn(
                        delay: Duration(milliseconds: 250 + i * _stepMs),
                        from: 0.6,
                        child: AnswerCard(
                          answer: answer,
                          correction: _correction(l10n, answer),
                        ),
                      ),
                    ),
                ],
                _SectionTitle(l10n.leaderboard),
                BounceIn(
                  delay: Duration(
                    milliseconds: 300 + (mine?.answers.length ?? 0) * _stepMs,
                  ),
                  from: 0.8,
                  slideY: 0.2,
                  child: GameCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (final (rank, p) in room.ranking.indexed)
                          _LeaderboardRow(
                            rank: rank + 1,
                            player: p,
                            gained: roundScores[p.clientId],
                            isMe: p.clientId == widget.myId,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (room.nextRoundAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '⏳ ${l10n.nextRoundIn(nextIn)}',
                key: const Key('next_round_in'),
                textAlign: TextAlign.center,
                style: fredoka(
                  size: 18,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: fredoka(size: 18, weight: FontWeight.w700, color: AppColors.white),
    ),
  );
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.player,
    required this.gained,
    required this.isMe,
  });

  final int rank;
  final RoomPlayer player;
  final int? gained;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: isMe ? AppColors.yellow.withValues(alpha: 0.25) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: rank <= 3
                ? GameIcon(GameIconKind.medal(rank), size: 26)
                : Text(
                    '$rank',
                    style: fredoka(size: 20, weight: FontWeight.w700),
                  ),
          ),
          PlayerAvatar(
            nickname: player.nickname,
            seed: player.clientId,
            size: 36,
            connected: player.connected,
            bot: player.bot,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${player.nickname} (${l10n.youBadge})' : player.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fredoka(size: 17, weight: FontWeight.w600),
            ),
          ),
          if (gained != null)
            Text(
              '+$gained  ',
              style: fredoka(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          Text(
            l10n.pointsShort(player.score),
            style: fredoka(
              size: 17,
              weight: FontWeight.w700,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}
