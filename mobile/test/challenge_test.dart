import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/career/career_levels.dart';
import 'package:letter_battle/features/career/career_screen.dart';
import 'package:letter_battle/features/career/elimination_screen.dart';
import 'package:letter_battle/features/online/room_screen.dart';
import 'package:letter_battle/features/game/data/challenge.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/game/data/solo_game_api.dart';
import 'package:letter_battle/features/game/offline/offline_dictionary.dart';
import 'package:letter_battle/features/game/solo_game_controller.dart';
import 'package:letter_battle/features/game/solo_game_screen.dart';
import 'package:letter_battle/main.dart';

import 'online_test.dart' show Harness;
import 'solo_game_test.dart' show FakeServer;

GameFeedback feedbackWith(AppSettings settings) => GameFeedback(
  audio: SilentGameAudio(),
  settings: settings,
  ambientMotion: false,
);

/// Joue une manche : réponse [city] puis « Terminer ».
Future<void> playRound(WidgetTester tester, String city) async {
  final field = find.byKey(const Key('field_city'));
  // Compte à rebours (3 pas) + startRound async. Éviter pumpAndSettle : le
  // glow du champ actif tourne en boucle.
  for (var i = 0; i < 10; i++) {
    if (field.evaluate().isNotEmpty) break;
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(field, findsOneWidget);
  await tester.enterText(field, city);
  await tester.tap(find.byKey(const Key('key_finish')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<SoloGameController> pumpChallenge(
  WidgetTester tester,
  FakeServer server,
  SoloChallenge challenge,
  GameFeedback feedback,
) async {
  final api = SoloGameApi(server.api);
  final game = SoloGame.fromJson(server.game());
  // Horloge figée : le chrono de manche ne dépend pas du temps réel du test.
  final clock = DateTime(2026, 1, 1, 12);
  final controller = SoloGameController(
    api: api,
    game: game,
    challenge: challenge,
    countdownStep: const Duration(milliseconds: 10),
    tick: const Duration(milliseconds: 50),
    now: () => clock,
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
  // Chargé une fois, hors du temps simulé des tests (décompression réelle).
  setUpAll(OfflineDictionary.load);

  test('career has 60 levels that get harder', () {
    expect(careerLevels, hasLength(60));
    expect(careerWorldCount * levelsPerWorld, 60);
    for (final level in careerLevels) {
      expect(SoloGameSettings.durationOptions, contains(level.roundDuration));
      expect(SoloGameSettings.roundOptions, contains(level.rounds));
      expect(level.target, lessThan(level.twoStars));
      expect(level.twoStars, lessThan(level.threeStars));
      expect(level.threeStars, lessThanOrEqualTo(level.maxScore));
    }
    expect(careerLevels.first.categories, [Category.city, Category.country]);
    expect(careerLevels[9].categories, hasLength(4));
    expect(careerLevels[levelsPerWorld].categories, Category.classic);
    expect(careerLevels[levelsPerWorld + 5].categories, [
      ...Category.classic,
      Category.femaleName,
    ]);
    expect(careerLevels[levelsPerWorld * 2].categories, careerCategoryOrder);
    expect(careerLevels.last.categories, careerCategoryOrder);
    expect(careerLevels.first.difficulty, Difficulty.easy);
    expect(careerLevels[levelsPerWorld].difficulty, Difficulty.normal);
    expect(careerLevels.last.difficulty, Difficulty.hard);
    expect(careerLevels.last.world, 3);
    expect(careerLevels.last.roundDuration, 45);
    for (final level in careerLevels) {
      if (level.categories.length >= Category.many) {
        expect(level.roundDuration, greaterThanOrEqualTo(45));
      }
    }
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
    settings.recordCareer(1, 3);
    expect(settings.careerStars[1], 3, reason: 'a better replay replaces it');
    settings.recordCareerLetters(1, ['M', 'A', 'm']);
    expect(settings.careerLettersOf(1), 'MA');
    settings.recordCareerAnswers(0, {
      Category.country: ['Sénégal', 'Espagne'],
      Category.city: ['Paris'],
    });
    settings.recordCareerAnswers(0, {
      Category.country: ['Sénégal', 'Suisse'],
    });
    expect(settings.careerBannedAnswers(0)[Category.country], [
      'Sénégal',
      'Espagne',
      'Suisse',
    ]);
    expect(settings.careerBannedAnswers(1), isEmpty);
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
    await tester.pump();

    // Manche 2 : rien trouvé, éliminé.
    await playRound(tester, '');
    expect(find.text('ELIMINATED! You needed 10 pts'), findsOneWidget);
    expect(controller.eliminatedAt, 2);
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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
    expect(find.text('RULES'), findsOneWidget, reason: 'shown on first visit');
    expect(find.textContaining('60 levels'), findsOneWidget);
    expect(find.textContaining('same world'), findsOneWidget);
    await tester.ensureVisible(find.text('GOT IT'));
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 180'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'level 2 is open');
    expect(find.text('3'), findsNothing, reason: 'level 3 shows a lock');

    await tester.tap(find.byKey(const Key('career_rules')));
    await tester.pumpAndSettle();
    expect(find.text('RULES'), findsOneWidget);
    expect(find.textContaining("girl's name"), findsOneWidget);
    expect(find.textContaining("boy's name"), findsOneWidget);
    await tester.ensureVisible(find.text('GOT IT'));
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('career_level_1')));
    await tester.pumpAndSettle();
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    Navigator.of(tester.element(find.text('PLAY AGAIN'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('career_level_2')));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.byKey(const Key('play_level')), findsOneWidget);
  });

  testWidgets('without a server, a career level starts offline at once', (
    tester,
  ) async {
    final h = Harness();
    final server = FakeServer();
    await h.start(tester, CareerScreen(apiClient: server.api));
    await tester.ensureVisible(find.text('GOT IT'));
    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    h.refuseConnections = true;
    h.socket.close();
    await tester.pumpAndSettle();
    expect(h.client.unreachable, isTrue);

    await tester.tap(find.byKey(const Key('career_level_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('play_level')));
    await tester.pump();
    expect(find.byKey(const Key('career_launching')), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SoloGameScreen), findsOneWidget);
    expect(server.createdWith, isNull, reason: 'no wait on the server');

    // Le serveur revient : plus de reconnexion en attente à la fin du test.
    h.refuseConnections = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('knockout: invite friends opens a knockout room', (tester) async {
    final h = Harness();
    await h.start(tester, EliminationScreen(apiClient: FakeServer().api));
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('invite_friends')),
      200,
      scrollable: list,
    );
    await tester.drag(list, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite_friends')));
    await tester.pump();
    final create = h.socket.sent.lastWhere((m) => m['type'] == 'create_room');
    final settings = create['settings'] as Map<String, dynamic>;
    expect(settings['format'], 'elimination');
    expect(settings['rounds'], 15);
    expect(settings['round_duration'], 30);
    expect(settings['kind'], 'classic');
    expect(settings['stake'], 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RoomScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
