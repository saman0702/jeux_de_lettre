import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/career/career_levels.dart';
import 'package:letter_battle/features/career/career_screen.dart';
import 'package:letter_battle/features/game/data/challenge.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/game/data/solo_game_api.dart';
import 'package:letter_battle/features/game/solo_game_controller.dart';
import 'package:letter_battle/features/game/solo_game_screen.dart';
import 'package:letter_battle/main.dart';

import 'solo_game_test.dart' show FakeServer;

GameFeedback feedbackWith(AppSettings settings) => GameFeedback(
  audio: SilentGameAudio(),
  settings: settings,
  ambientMotion: false,
);

/// Joue une manche : réponse [city] puis « Terminer ».
Future<void> playRound(WidgetTester tester, String city) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('field_city')), city);
  await tester.tap(find.byKey(const Key('key_finish')));
  await tester.pumpAndSettle();
}

Future<SoloGameController> pumpChallenge(
  WidgetTester tester,
  FakeServer server,
  SoloChallenge challenge,
  GameFeedback feedback,
) async {
  final api = SoloGameApi(server.api);
  final game = SoloGame.fromJson(server.game());
  final controller = SoloGameController(
    api: api,
    game: game,
    challenge: challenge,
    countdownStep: const Duration(milliseconds: 10),
    tick: const Duration(milliseconds: 50),
  );
  tester.platformDispatcher.localesTestValue = const [Locale('en')];
  await tester.pumpWidget(
    LetterBattleApp(
      feedback: feedback,
      home: SoloGameScreen(
        api: api,
        game: game,
        apiClient: server.api,
        controller: controller,
        challenge: challenge,
      ),
    ),
  );
  return controller;
}

void main() {
  test('career has 30 levels that get harder', () {
    expect(careerLevels, hasLength(30));
    for (final level in careerLevels) {
      expect(SoloGameSettings.durationOptions, contains(level.roundDuration));
      expect(SoloGameSettings.roundOptions, contains(level.rounds));
      expect(level.target, lessThan(level.twoStars));
      expect(level.twoStars, lessThan(level.threeStars));
      expect(level.threeStars, lessThanOrEqualTo(level.maxScore));
    }
    expect(careerLevels.first.categories, hasLength(2));
    expect(careerLevels.first.difficulty, Difficulty.easy);
    expect(careerLevels.last.difficulty, Difficulty.hard);
    expect(careerLevels.last.roundDuration, 15);
    final level = careerLevels.first;
    expect(level.starsFor(level.target - 10), 0);
    expect(level.starsFor(level.target), 1);
    expect(level.starsFor(level.maxScore), 3);
  });

  test('a level opens once the previous one has a star', () {
    final settings = AppSettings.inMemory();
    expect(settings.careerUnlocked(1), isTrue);
    expect(settings.careerUnlocked(2), isFalse);
    settings.recordCareer(1, 2);
    settings.recordCareer(1, 1);
    expect(settings.careerStars[1], 2, reason: 'best result kept');
    expect(settings.careerUnlocked(2), isTrue);
    expect(settings.recordElimination(4), isTrue);
    expect(settings.recordElimination(3), isFalse);
    expect(settings.eliminationBest, 4);
  });

  testWidgets('knockout: below the minimum, the game stops', (tester) async {
    final server = FakeServer(totalRounds: 15);
    final settings = AppSettings.inMemory();
    final controller = await pumpChallenge(
      tester,
      server,
      const EliminationChallenge(),
      feedbackWith(settings),
    );

    // Manche 1 : 10 points, le minimum est 10.
    expect(find.text('Min. 10 pts'), findsNothing);
    await playRound(tester, 'Madrid');
    expect(find.text('10 PTS MINIMUM: PASSED!'), findsOneWidget);
    await tester.tap(find.text('NEXT ROUND'));
    await tester.pumpAndSettle();

    // Manche 2 : rien trouvé, éliminé.
    await playRound(tester, '');
    expect(find.text('ELIMINATED! You needed 10 pts'), findsOneWidget);
    expect(controller.eliminatedAt, 2);
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminated!'), findsOneWidget);
    expect(find.text('You lasted 1 round out of 15'), findsOneWidget);
    expect(find.text('New record: 1 rounds!'), findsOneWidget);
    expect(settings.eliminationBest, 1);
  });

  testWidgets('career: reaching the goal gives stars and the next level', (
    tester,
  ) async {
    final server = FakeServer();
    final settings = AppSettings.inMemory();
    // Niveau d'essai d'une manche : objectif 10, étoiles à 20 et 30.
    const level = CareerLevel(
      number: 1,
      world: 0,
      difficulty: Difficulty.easy,
      categories: [Category.city, Category.fruit],
      roundDuration: 30,
      rounds: 1,
      target: 10,
    );
    await pumpChallenge(tester, server, level, feedbackWith(settings));
    await playRound(tester, 'Madrid');
    expect(find.text('Goal: 10 / 10 pts'), findsOneWidget);
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();
    expect(find.text('Level 1 cleared!'), findsOneWidget);
    expect(find.byKey(const Key('next_level_button')), findsOneWidget);
    expect(settings.careerStars[1], 1);
  });

  testWidgets('the career map locks the levels not yet reached', (
    tester,
  ) async {
    final settings = AppSettings.inMemory()..recordCareer(1, 3);
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(
        feedback: feedbackWith(settings),
        home: CareerScreen(apiClient: FakeServer().api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 / 90'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'level 2 is open');
    expect(find.text('3'), findsNothing, reason: 'level 3 shows a lock');

    await tester.tap(find.byKey(const Key('career_level_2')));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.byKey(const Key('play_level')), findsOneWidget);
  });
}
