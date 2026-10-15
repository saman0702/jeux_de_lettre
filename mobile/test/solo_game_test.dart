import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/game/data/solo_game_api.dart';
import 'package:letter_battle/features/game/solo_game_controller.dart';
import 'package:letter_battle/features/game/solo_game_screen.dart';
import 'package:letter_battle/features/game/solo_setup_screen.dart';
import 'package:letter_battle/main.dart';

/// Minimal in-memory version of the solo API.
class FakeServer {
  FakeServer({this.totalRounds = 1, this.roundSeconds = 30});

  final int totalRounds;
  final int roundSeconds;
  int roundsPlayed = 0;
  int totalScore = 0;
  Map<String, dynamic>? createdWith;
  final List<Map<String, dynamic>> submissions = [];
  final List<Map<String, dynamic>> hintCalls = [];
  int hintsLeft = 3;

  Map<String, dynamic> game() => {
    'id': 'g1',
    'mode': 'solo',
    'language': 'en',
    'difficulty': 'normal',
    'categories': ['city', 'fruit'],
    'total_rounds': totalRounds,
    'round_duration': roundSeconds,
    'status': roundsPlayed >= totalRounds ? 'finished' : 'playing',
    'nickname': 'Player',
    'total_score': totalScore,
    'rounds_played': roundsPlayed,
    'hints_left': hintsLeft,
  };

  late final client = MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/v1/solo/games') {
      createdWith = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(game(), 201);
    }
    if (path.endsWith('/hint/pick')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      hintCalls.add({'pick': body['choice']});
      return _json({
        'category': body['category'],
        'correct': body['choice'] == 'Madrid',
        'answer': 'Madrid',
      });
    }
    if (path.endsWith('/hint')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      hintCalls.add({'request': body['category']});
      hintsLeft--;
      return _json({
        'category': body['category'],
        'options': ['Mangue', 'Madrid', 'Maroc', 'Mouton'],
        'hints_left': hintsLeft,
      });
    }
    if (path.endsWith('/rounds')) {
      final now = DateTime.now().toUtc();
      return _json({
        'number': roundsPlayed + 1,
        'letter': 'M',
        'duration': roundSeconds,
        'started_at': now.toIso8601String(),
        'ends_at': now.add(Duration(seconds: roundSeconds)).toIso8601String(),
        'server_time': now.toIso8601String(),
      }, 201);
    }
    if (path.endsWith('/submit')) {
      final answers = (jsonDecode(request.body) as Map)['answers'] as Map;
      submissions.add(Map<String, dynamic>.from(answers));
      final city = answers['city'] as String? ?? '';
      final points = city == 'Madrid' ? 10 : 0;
      roundsPlayed++;
      totalScore += points;
      return _json({
        'round': {
          'number': roundsPlayed,
          'letter': 'M',
          'answers': [
            {
              'category': 'city',
              'value': city,
              'status': points > 0 ? 'valid' : 'empty',
              'points': points,
              'matched_value': points > 0 ? 'Madrid' : null,
            },
            {
              'category': 'fruit',
              'value': '',
              'status': 'empty',
              'points': 0,
              'matched_value': null,
            },
          ],
          'round_score': points,
          'elapsed_ms': 4200,
        },
        'game': game(),
      });
    }
    return _json({'detail': 'not_found'}, 404);
  });

  ApiClient get api => ApiClient(client: client, baseUrl: 'http://test');

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

GameFeedback testFeedback() => GameFeedback(
  audio: SilentGameAudio(),
  settings: AppSettings.inMemory(),
  ambientMotion: false,
);

Future<SoloGameController> pumpGame(
  WidgetTester tester,
  FakeServer server, {
  DateTime Function()? now,
  GameFeedback? feedback,
}) async {
  final api = SoloGameApi(server.api);
  final game = SoloGame.fromJson(server.game());
  final controller = SoloGameController(
    api: api,
    game: game,
    countdownStep: const Duration(milliseconds: 10),
    tick: const Duration(milliseconds: 50),
    now: now ?? DateTime.now,
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
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('plays a full round and reaches the final screen', (
    tester,
  ) async {
    final server = FakeServer();
    final feedback = testFeedback();
    final audio = feedback.audio as SilentGameAudio;
    await pumpGame(tester, server, feedback: feedback);

    expect(find.text('3'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('letter')), findsOneWidget);
    expect(find.text('Round 1 / 1'), findsOneWidget);
    expect(
      audio.played,
      containsAllInOrder([
        Sfx.countdown,
        Sfx.countdown,
        Sfx.countdown,
        Sfx.go,
        Sfx.reveal,
      ]),
    );
    expect(audio.musicPlaying, isFalse);

    await tester.enterText(find.byKey(const Key('field_city')), 'Madrid');
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    expect(server.submissions.single, {'city': 'Madrid', 'fruit': ''});
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('+10'), findsWidgets);
    expect(find.text('⏱ Finished in 4.2s'), findsOneWidget);
    expect(
      audio.played,
      containsAllInOrder([Sfx.valid, Sfx.invalid, Sfx.points]),
    );

    await tester.tap(find.text('SEE RESULTS'));
    await tester.pumpAndSettle();

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(audio.played.last, Sfx.victory);
    expect(find.byKey(const Key('total_score')), findsOneWidget);
    expect(find.text('10 pts'), findsWidgets);
  });

  testWidgets('submits automatically when the server time is up', (
    tester,
  ) async {
    final server = FakeServer(roundSeconds: 15);
    var clock = DateTime.now();
    await pumpGame(tester, server, now: () => clock);

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();
    expect(server.submissions, isEmpty);

    await tester.enterText(find.byKey(const Key('field_city')), 'Mon');
    clock = clock.add(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(server.submissions.single['city'], 'Mon');
    expect(find.text('No answer'), findsWidgets);
  });

  testWidgets('no sound effect when sounds are turned off', (tester) async {
    final feedback = testFeedback();
    feedback.settings.sound = false;
    await pumpGame(tester, FakeServer(), feedback: feedback);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('letter')), findsOneWidget);
    expect((feedback.audio as SilentGameAudio).played, isEmpty);
  });

  test('remaining time follows the server clock, not the phone clock', () {
    final phoneNow = DateTime.utc(2026, 1, 1, 12, 0, 0);
    // Phone clock is 10 minutes ahead of the server.
    final round = GameRound.fromJson({
      'number': 1,
      'letter': 'A',
      'duration': 30,
      'ends_at': '2026-01-01T11:50:30Z',
      'server_time': '2026-01-01T11:50:00Z',
    }, receivedAt: phoneNow);

    expect(round.remaining(phoneNow), const Duration(seconds: 30));
    expect(
      round.remaining(phoneNow.add(const Duration(seconds: 40))),
      Duration.zero,
    );
  });

  testWidgets('setup screen creates a game with the chosen options', (
    tester,
  ) async {
    final server = FakeServer();
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(
        feedback: testFeedback(),
        home: SoloSetupScreen(apiClient: server.api),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('10'));
    await tester.tap(find.text('45s'));
    await tester.tap(find.text('🐘 Animal'));
    await tester.ensureVisible(find.text('Hard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard'));
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(server.createdWith, {
      'language': 'en',
      'difficulty': 'hard',
      'categories': ['city', 'country', 'fruit'],
      'rounds': 10,
      'round_duration': 45,
      'nickname': 'Player',
    });
    expect(find.byType(SoloGameScreen), findsOneWidget);
  });

  testWidgets('a hint shows four options and locks the field', (tester) async {
    final server = FakeServer();
    final feedback = testFeedback();
    await pumpGame(tester, server, feedback: feedback);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hint_city')));
    await tester.pumpAndSettle();
    expect(find.text('Only one of these words is right!'), findsOneWidget);
    expect(find.text('Maroc'), findsOneWidget);

    await tester.tap(find.text('Madrid'));
    await tester.pumpAndSettle();
    expect(server.hintCalls, [
      {'request': 'city'},
      {'pick': 'Madrid'},
    ]);
    expect(find.text('Madrid'), findsOneWidget);
    expect(find.byKey(const Key('hint_city')), findsNothing, reason: 'field is locked');
    expect(find.text('2'), findsOneWidget, reason: 'two hints left on the fruit button');
    expect((feedback.audio as SilentGameAudio).played, contains(Sfx.valid));

    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();
    expect(server.submissions.single['city'], 'Madrid');
  });
}
