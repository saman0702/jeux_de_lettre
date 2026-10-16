import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/widgets/game_background.dart';

import 'solo_game_test.dart' show FakeServer, pumpGame;

void main() {
  test('les lettres du fond bougent en continu, sans jamais sauter', () {
    const size = Size(400, 860);
    const step = 1 / 60; // une image
    for (var i = 0; i < backgroundLetterCount; i++) {
      // Inclut une longue session et d'anciennes limites de boucle.
      for (final start in [0.0, 39.9, 3600.0, 86400.0]) {
        for (var t = start; t < start + 0.5; t += step) {
          final (a, angleA) = letterPose(i, t, size);
          final (b, angleB) = letterPose(i, t + step, size);
          expect((b - a).distance, lessThan(1), reason: 'lettre $i à ${t}s');
          expect((angleB - angleA).abs(), lessThan(0.01));
        }
      }
    }
  });

  test('a sound or tune never repeats twice in a row', () {
    final random = Random(3);
    int? last;
    for (var i = 0; i < 500; i++) {
      final next = pickOtherIndex(random, 3, last);
      expect(next, inInclusiveRange(0, 2));
      expect(next, isNot(last));
      last = next;
    }
    expect(pickOtherIndex(random, 1, 0), 0);
  });

  testWidgets('each round has its own background colours', (tester) async {
    final server = FakeServer(totalRounds: 2);
    await pumpGame(tester, server);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    GameBackground background() =>
        tester.widget<GameBackground>(find.byType(GameBackground));
    expect(background().palette, BackgroundPalette.forRound(1));

    await tester.tap(find.byKey(const Key('key_finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT ROUND'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(background().palette, BackgroundPalette.forRound(2));
    expect(BackgroundPalette.forRound(2), isNot(BackgroundPalette.forRound(1)));

    await tester.tap(find.byKey(const Key('key_finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();
    expect(background().palette, BackgroundPalette.victory);
  });
}
