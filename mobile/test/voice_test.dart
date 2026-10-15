import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/core/voice/announcements.dart';
import 'package:letter_battle/core/voice/announcer.dart';
import 'package:letter_battle/l10n/app_localizations_fr.dart';

import 'solo_game_test.dart' show FakeServer, pumpGame;

void main() {
  final say = Announcements(AppLocalizationsFr(), Random(1));
  const names = {'me': 'Blaise', 'flo': 'Flore', 'arn': 'Arnaud'};

  test('the round winner is congratulated', () {
    final line = say.roomRound(roundScores: {'me': 20, 'flo': 5}, names: names, me: 'me');
    expect(line, anyOf('Bravo Blaise, tu remportes la manche !', 'Excellent Blaise ! Manche gagnée !'));
  });

  test('when someone else wins, the player is encouraged', () {
    final line = say.roomRound(roundScores: {'me': 5, 'flo': 20}, names: names, me: 'me');
    expect(line, contains('Flore'));
    expect(
      line,
      anyOf(contains('Courage'), contains('Pas de panique'), contains('on lâche rien')),
    );
  });

  test('ties and empty rounds have their own lines', () {
    expect(say.roomRound(roundScores: {'me': 10, 'flo': 10}, names: names, me: 'me'), contains('Égalité'));
    expect(say.roomRound(roundScores: {'me': 0, 'flo': 0}, names: names, me: 'me'), contains('Personne'));
  });

  test('solo lines follow the score', () {
    expect(say.soloRound(40, 40), 'Superbe ! 40 points !');
    expect(say.soloRound(20, 40), 'Bien joué, 20 points !');
    expect(say.soloRound(10, 40), contains('mieux'));
    expect(say.soloRound(0, 40), contains('aucun point'));
  });

  test('final announcement names the winner', () {
    expect(say.roomGameOver(winnerId: 'flo', winnerName: 'Flore', me: 'me'), startsWith('Flore gagne la partie'));
    expect(say.roomGameOver(winnerId: 'me', winnerName: 'Blaise', me: 'me'), contains('tu gagnes'));
  });

  testWidgets('the announcer speaks after a round, unless the voice is off', (tester) async {
    for (final voice in [true, false]) {
      final announcer = SilentAnnouncer();
      final feedback = GameFeedback(
        audio: SilentGameAudio(),
        settings: AppSettings.inMemory()..voice = voice,
        announcer: announcer,
        ambientMotion: false,
      );
      final server = FakeServer();
      await pumpGame(tester, server, feedback: feedback);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field_city')), 'Madrid');
      await tester.tap(find.byKey(const Key('key_finish')));
      await tester.pumpAndSettle();

      expect(announcer.said, voice ? [contains('10 points')] : isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
