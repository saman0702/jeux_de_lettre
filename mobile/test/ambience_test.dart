import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/widgets/game_background.dart';

import 'solo_game_test.dart' show FakeServer, pumpGame;

void main() {
  test('floating letters drift smoothly, with no jump ever', () {
    const size = Size(400, 860);
    const step = 1 / 60; // one frame
    for (var i = 0; i < floatingLetterCount; i++) {
      // Includes the old 40 s loop boundaries and a long session.
      for (final start in [0.0, 39.9, 40.0, 79.95, 3600.0, 86400.0]) {
        for (var t = start; t < start + 0.5; t += step) {
          final (x0, y0, a0) = floatingLetterPose(i, t, size);
          final (x1, y1, a1) = floatingLetterPose(i, t + step, size);
          final onScreen = y0 > -60 && y0 < size.height + 60;
          if (onScreen) {
            expect((y1 - y0).abs(), lessThan(2), reason: 'letter $i at ${t}s');
          }
          expect((x1 - x0).abs(), lessThan(1));
          expect((a1 - a0).abs(), lessThan(0.01));
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
    expect(background().focusLetter, 'M');

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
