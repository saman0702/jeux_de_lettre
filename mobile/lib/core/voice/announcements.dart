import 'dart:math';

import '../../l10n/app_localizations.dart';

/// Ce que dit le présentateur. Les variantes sont tirées au hasard pour ne pas
/// répéter la même phrase à chaque manche.
class Announcements {
  Announcements(this.l10n, [Random? random]) : _random = random ?? Random();

  final AppLocalizations l10n;
  final Random _random;

  T _pick<T>(List<T> options) => options[_random.nextInt(options.length)];

  String get _encourage =>
      _pick([l10n.voiceEncourage1, l10n.voiceEncourage2, l10n.voiceEncourage3]);

  /// Manche solo : félicite ou encourage selon la part des points gagnés.
  String soloRound(int points, int maxPoints) {
    final ratio = maxPoints == 0 ? 0 : points / maxPoints;
    if (points == 0) return l10n.voiceSoloZero;
    if (ratio >= 0.75) return l10n.voiceSoloGreat(points);
    if (ratio >= 0.4) return l10n.voiceSoloGood(points);
    return l10n.voiceSoloLow;
  }

  /// Manche multijoueur, du point de vue de ce joueur.
  String roomRound({
    required Map<String, int> roundScores,
    required Map<String, String> names,
    required String me,
  }) {
    final best = roundScores.values.fold(0, max);
    if (best == 0) return l10n.voiceNobodyScored;
    final winners = [
      for (final e in roundScores.entries)
        if (e.value == best) e.key,
    ];
    if (winners.length > 1) return l10n.voiceTie;
    final winner = winners.single;
    if (winner == me) {
      return _pick([l10n.voiceYouWinRound1, l10n.voiceYouWinRound2])(
        names[me] ?? '',
      );
    }
    final announce = _pick([
      l10n.voiceOtherWinsRound1,
      l10n.voiceOtherWinsRound2,
    ]);
    return '${announce(names[winner] ?? '')} $_encourage';
  }

  String roomGameOver({
    required String winnerId,
    required String winnerName,
    required String me,
  }) => winnerId == me
      ? l10n.voiceYouWinGame(winnerName)
      : l10n.voiceOtherWinsGame(winnerName);

  String soloGameOver(int points) => l10n.voiceSoloGameEnd(points);
}
