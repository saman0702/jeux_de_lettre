import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/iq/game_hub_screen.dart';
import 'package:letter_battle/features/iq/iq_daily_screen.dart';
import 'package:letter_battle/features/iq/iq_hub_screen.dart';
import 'package:letter_battle/features/iq/iq_models.dart';
import 'package:letter_battle/features/iq/iq_setup_screen.dart';
import 'package:letter_battle/features/iq/iq_solo_screen.dart';
import 'package:letter_battle/features/iq/iq_solo_source.dart';
import 'package:letter_battle/features/career/elimination_screen.dart';
import 'package:letter_battle/features/game/solo_setup_screen.dart';
import 'package:letter_battle/features/online/room_screen.dart';

import 'solo_game_test.dart' show FakeServer;
import 'online_test.dart' show Harness, me, player, pumpFor, roomEvent;

Map<String, dynamic> sequenceJson({bool withAnswer = true}) => {
  'id': 'seq-1',
  'kind': 'sequence',
  'level': 1,
  'input': 'number',
  'prompt': {
    'fr': 'Quel nombre vient ensuite ?',
    'en': 'Which number comes next?',
  },
  'items': ['2', '4', '6', '?'],
  if (withAnswer) 'answer': '8',
  if (withAnswer)
    'explanation': {'fr': 'On ajoute 2.', 'en': 'Add 2 each time.'},
};

Map<String, dynamic> oddJson({bool withAnswer = true}) => {
  'id': 'odd-1',
  'kind': 'odd',
  'level': 3,
  'input': 'choice',
  'prompt': {'fr': "Quel est l'intrus ?", 'en': 'Which is the odd one out?'},
  'choices': {
    'fr': ['Chat', 'Chien', 'Pomme', 'Lion'],
    'en': ['Cat', 'Dog', 'Apple', 'Lion'],
  },
  if (withAnswer) 'answer': '2',
  if (withAnswer)
    'explanation': {
      'fr': "La pomme n'est pas un animal.",
      'en': 'An apple is not an animal.',
    },
};

/// Paramètres d'un salon QI, pour le faux serveur.
Map<String, dynamic> iqRoom(Map<String, dynamic> event) {
  final room = event['room'] as Map<String, dynamic>;
  room['settings'] = {
    ...room['settings'] as Map<String, dynamic>,
    'categories': <String>[],
    'game': 'iq',
    'iq_speed_bonus': true,
    'iq_penalty': true,
  };
  return event;
}

/// Écran de téléphone assez haut pour voir l'énigme et le clavier.
void tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  group('IQ rules', () {
    test('answers are compared like on the server', () {
      final seq = IqPuzzle.fromJson(sequenceJson());
      expect(seq.isCorrect('8'), isTrue);
      expect(seq.isCorrect(' 8,0 '), isTrue);
      expect(seq.isCorrect('9'), isFalse);
      expect(seq.isCorrect(''), isFalse);
      final odd = IqPuzzle.fromJson(oddJson());
      expect(odd.isCorrect('2'), isTrue);
      expect(odd.answerText('en'), 'Apple');
      expect(odd.answerText('fr'), 'Pomme');
    });

    test('scoring options: speed bonus and wrong-answer penalty', () {
      const total = Duration(seconds: 30);
      const both = IqScoring(speedBonus: true, penalty: true);
      expect(
        both.points(
          correct: true,
          answered: true,
          elapsed: Duration.zero,
          duration: total,
        ),
        20,
      );
      expect(
        both.points(
          correct: true,
          answered: true,
          elapsed: const Duration(seconds: 15),
          duration: total,
        ),
        15,
      );
      expect(
        both.points(
          correct: false,
          answered: true,
          elapsed: Duration.zero,
          duration: total,
        ),
        -5,
      );
      // Pas de malus si le temps est écoulé sans réponse.
      expect(
        both.points(
          correct: false,
          answered: false,
          elapsed: total,
          duration: total,
        ),
        0,
      );
      const plain = IqScoring(speedBonus: false);
      expect(
        plain.points(
          correct: true,
          answered: true,
          elapsed: Duration.zero,
          duration: total,
        ),
        10,
      );
      expect(
        plain.points(
          correct: false,
          answered: true,
          elapsed: Duration.zero,
          duration: total,
        ),
        0,
      );
    });

    test('estimated IQ goes from 70 to 145, hard puzzles weigh more', () {
      expect(iqEstimate([(1, false), (3, false)]), 70);
      expect(iqEstimate([(1, true), (3, true)]), 145);
      expect(
        iqEstimate([(3, true), (1, false)]),
        greaterThan(iqEstimate([(1, true), (3, false)])),
      );
    });

    test('difficulty ramps up during the game', () {
      expect(
        [for (var n = 1; n <= 10; n++) iqLevelFor(n, 10, Difficulty.normal)],
        [1, 1, 1, 1, 2, 2, 2, 3, 3, 3],
      );
      expect(iqLevelFor(1, 10, Difficulty.hard), 2);
      expect(iqLevelFor(10, 10, Difficulty.easy), 2);
    });

    test('offline puzzles come from the bundled file, all different', () {
      final raw = jsonDecode(
        File('assets/data/iq_puzzles.json').readAsStringSync(),
      ) as List;
      final puzzles = offlinePuzzles(
        raw,
        count: 15,
        difficulty: Difficulty.normal,
        random: Random(1),
      );
      expect(puzzles, hasLength(15));
      expect({for (final p in puzzles) p.id}, hasLength(15));
      expect(puzzles.first.level, 1);
      expect(puzzles.last.level, 3);
      for (final p in puzzles) {
        expect(p.answer, isNotNull);
        expect(p.typed || p.choicesIn('en').length == 4, isTrue);
      }
    });
  });

  testWidgets('solo IQ: type a number, pick a choice, see the estimated IQ', (
    tester,
  ) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(
      tester,
      IqSoloScreen(
        rounds: 2,
        duration: 30,
        difficulty: Difficulty.normal,
        scoring: const IqScoring(speedBonus: false, penalty: true),
        puzzles: [
          IqPuzzle.fromJson(sequenceJson()),
          IqPuzzle.fromJson(oddJson()),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Which number comes next?'), findsOneWidget);

    await tapKey(tester, 'iq_key_8');
    expect(
      find.descendant(
        of: find.byKey(const Key('iq_typed')),
        matching: find.text('8'),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'iq_submit');
    expect(find.byKey(const Key('iq_answer')), findsOneWidget);
    expect(find.text('Add 2 each time.'), findsOneWidget);

    await tapKey(tester, 'iq_next');
    expect(find.text('Which is the odd one out?'), findsOneWidget);
    await tapKey(tester, 'iq_choice_0');
    // Mauvaise réponse : la bonne est montrée avec l'explication.
    expect(find.text('An apple is not an animal.'), findsOneWidget);

    await tapKey(tester, 'iq_next');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const Key('iq_estimate')), findsOneWidget);
    // 1 bonne sur 2 : 10 − 5 = 5 points.
    expect(find.text('1 right answers out of 2 · 5 points'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('solo IQ without an answer moves on when time is up', (
    tester,
  ) async {
    var now = DateTime(2026, 1, 1, 12);
    tallPhone(tester);
    final h = Harness();
    await h.start(
      tester,
      IqSoloScreen(
        rounds: 1,
        duration: 15,
        difficulty: Difficulty.normal,
        scoring: const IqScoring(penalty: true),
        puzzles: [IqPuzzle.fromJson(sequenceJson())],
        now: () => now,
      ),
    );
    now = now.add(const Duration(seconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const Key('iq_answer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Rooms" lets you pick the game, IQ opens the IQ space', (
    tester,
  ) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const GameHubScreen());
    expect(find.text('Geography & Nature'), findsOneWidget);
    await tester.tap(find.byKey(const Key('game_iq')));
    await tester.pumpAndSettle();
    expect(find.byType(IqHubScreen), findsOneWidget);
    for (final key in ['iq_create', 'iq_join', 'iq_bots']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.byKey(const Key('iq_solo')),
      findsNothing,
      reason: 'solo IQ lives in free solo',
    );
    expect(h.socket.sentTypes, contains('subscribe_rooms'));

    // Les salons QI publics sont listés, pas ceux du Petit Bac.
    h.socket.push({
      'type': 'room_list',
      'rooms': [
        {
          'code': 'IQ123',
          'quick': false,
          'host': 'Kevin',
          'players': 1,
          'max_players': 8,
          'language': 'en',
          'rounds': 10,
          'round_duration': 30,
          'game': 'iq',
        },
        {
          'code': 'ABC12',
          'quick': false,
          'host': 'Lea',
          'players': 1,
          'max_players': 8,
          'language': 'en',
          'rounds': 5,
          'round_duration': 30,
        },
      ],
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iq_room_IQ123')), findsOneWidget);
    expect(find.byKey(const Key('iq_room_ABC12')), findsNothing);
  });

  testWidgets('IQ against bots creates an IQ room with the chosen options', (
    tester,
  ) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const IqSetupScreen(mode: IqSetupMode.bots));
    await tester.tap(find.text('3').first);
    await tester.ensureVisible(find.byKey(const Key('iq_penalty')));
    await tester.tap(find.byKey(const Key('iq_penalty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('iq_start')));
    await tester.pump();

    final create = h.socket.sent.lastWhere((m) => m['type'] == 'create_room');
    final settings = create['settings'] as Map<String, dynamic>;
    expect(settings['game'], 'iq');
    expect(settings['iq_penalty'], isTrue);
    expect(settings['iq_speed_bonus'], isTrue);
    expect(settings['rounds'], 10);
    expect(create['bots'], {'count': 3, 'level': 'normal'});
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RoomScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'online solo: the server checks answers, jokers cost coins, coins are won',
    (tester) async {
      final calls = <String>[];
      Map<String, dynamic> game({
        int extra = 0,
        List<String> used = const [],
      }) => {
        'id': 'g1',
        'mode': 'solo',
        'number': 1,
        'total': 1,
        'duration': 30,
        'extra_seconds': extra,
        'score': 0,
        'jokers_used': used,
        'joker_prices': {'fifty': 3, 'hint': 3, 'time': 3, 'skip': 5},
        'puzzle': sequenceJson(withAnswer: false),
      };
      Map<String, dynamic> wallet(int coins, int gained) => {
        'coins': coins,
        'coins_gained': gained,
        'points_to_next_coin': 20,
        'level': 1,
      };
      final api = ApiClient(
        client: MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          final body = switch (request.url.path) {
            '/api/v1/iq/solo' => game(),
            '/api/v1/iq/sessions/g1/joker' => {
              'kind': 'time',
              'price': 3,
              'extra_seconds': 15,
              'wallet': wallet(7, 0),
              'game': game(extra: 15, used: ['time']),
            },
            '/api/v1/iq/sessions/g1/answer' => {
              'number': 1,
              'total': 1,
              'answer': '8',
              'correct': true,
              'late': false,
              'points': 20,
              'score': 20,
              'puzzle': sequenceJson(),
              'finished': true,
              'wallet': wallet(8, 1),
              'correct_count': 1,
              'iq': 145,
            },
            _ => <String, dynamic>{},
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      tallPhone(tester);
      final h = Harness();
      await h.start(
        tester,
        IqSetupScreen(mode: IqSetupMode.solo, apiClient: api),
      );
      await tester.tap(find.byKey(const Key('iq_start')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(calls, contains('POST /api/v1/iq/solo'));
      expect(find.text('Which number comes next?'), findsOneWidget);
      // Énigme à nombre : indice (pas de 50/50), +15 s et passer.
      expect(find.byKey(const Key('iq_joker_hint')), findsOneWidget);
      expect(find.byKey(const Key('iq_joker_fifty')), findsNothing);
      await tapKey(tester, 'iq_joker_time');
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(calls, contains('POST /api/v1/iq/sessions/g1/joker'));
      expect(h.online.wallet?.coins, 7);
      await tapKey(tester, 'iq_key_8');
      await tapKey(tester, 'iq_submit');
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(calls, contains('POST /api/v1/iq/sessions/g1/answer'));
      expect(find.byKey(const Key('iq_answer')), findsOneWidget);
      await tapKey(tester, 'iq_next');
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.text('145'), findsOneWidget);
      expect(find.byKey(const Key('iq_coins_won')), findsOneWidget);
      expect(h.online.wallet?.coins, 8);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('daily challenge shows the leaderboard and my rank', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'day': '2026-10-26',
            'count': 10,
            'prizes': [50, 30, 20],
            'played': true,
            'me': {
              'rank': 2,
              'client_id': me,
              'nickname': 'Blaise',
              'score': 120,
              'correct': 8,
              'elapsed_ms': 90000,
            },
            'top': [
              {
                'rank': 1,
                'client_id': 'kev',
                'nickname': 'Kevin',
                'score': 150,
                'correct': 9,
                'elapsed_ms': 80000,
              },
              {
                'rank': 2,
                'client_id': me,
                'nickname': 'Blaise',
                'score': 120,
                'correct': 8,
                'elapsed_ms': 90000,
              },
            ],
            'yesterday': [
              {
                'rank': 1,
                'client_id': 'lea',
                'nickname': 'Léa',
                'score': 170,
                'correct': 10,
                'elapsed_ms': 70000,
                'prize': 50,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, IqDailyScreen(apiClient: api));
    await tester.pumpAndSettle();
    expect(find.text('Your rank: 2'), findsOneWidget);
    expect(find.byKey(const Key('iq_daily_done')), findsOneWidget);
    expect(
      find.byKey(const Key('iq_daily_play')),
      findsNothing,
      reason: 'one try a day',
    );
    expect(find.byKey(const Key('iq_daily_row_kev')), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('IQ room: answer a puzzle, then see the reveal', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const RoomScreen());
    final now = DateTime.now().toUtc();
    h.socket.push(
      iqRoom(
        roomEvent(
          'round',
          round: {
            'number': 1,
            'letter': '',
            'duration': 30,
            'started_at': now.toIso8601String(),
            'ends_at': now.add(const Duration(seconds: 30)).toIso8601String(),
            'puzzle': oddJson(withAnswer: false),
          },
        ),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Which is the odd one out?'), findsOneWidget);
    expect(find.text('Apple'), findsWidgets);

    await tapKey(tester, 'iq_choice_2');
    expect(h.socket.sent.last, {
      'type': 'iq_answer',
      'round': 1,
      'answer': '2',
    });
    expect(find.byKey(const Key('iq_sent')), findsOneWidget);

    h.socket.push(
      iqRoom(
        roomEvent(
          'results',
          players: [
            player(me, 'Blaise', score: 18),
            player('kev', 'Kevin', score: -5),
          ],
          results: {
            'number': 1,
            'letter': '',
            'puzzle': oddJson(),
            'players': [
              {
                'client_id': me,
                'nickname': 'Blaise',
                'answers': [],
                'answer': '2',
                'correct': true,
                'round_score': 18,
              },
              {
                'client_id': 'kev',
                'nickname': 'Kevin',
                'answers': [],
                'answer': '0',
                'correct': false,
                'round_score': -5,
              },
            ],
            'examples': {},
            'eliminated': [],
          },
          nextRoundAt: now.add(const Duration(seconds: 8)),
        ),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const Key('iq_answer')), findsOneWidget);
    expect(find.text('An apple is not an animal.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('IQ relay: each player solves their own puzzle', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const RoomScreen());
    final now = DateTime.now().toUtc();
    final event = iqRoom(
      roomEvent(
        'round',
        round: {
          'number': 1,
          'letter': '',
          'duration': 30,
          'started_at': now.toIso8601String(),
          'ends_at': now.add(const Duration(seconds: 30)).toIso8601String(),
          'puzzle': null,
          'puzzles': {
            me: sequenceJson(withAnswer: false),
            'kev': oddJson(withAnswer: false),
          },
        },
      ),
    );
    ((event['room'] as Map)['settings'] as Map)['format'] = 'relay';
    h.socket.push(event);
    await pumpFor(tester, const Duration(milliseconds: 300));
    // Mon énigme à moi, pas celle de Kevin.
    expect(find.text('Which number comes next?'), findsOneWidget);
    expect(find.text('Which is the odd one out?'), findsNothing);
    await tapKey(tester, 'iq_key_8');
    await tapKey(tester, 'iq_submit');
    expect(h.socket.sent.last, {
      'type': 'iq_answer',
      'round': 1,
      'answer': '8',
    });

    final results = iqRoom(
      roomEvent(
        'results',
        results: {
          'number': 1,
          'letter': '',
          'puzzle': null,
          'players': [
            {
              'client_id': me,
              'nickname': 'Blaise',
              'answers': [],
              'answer': '8',
              'correct': true,
              'round_score': 15,
              'puzzle': sequenceJson(),
            },
            {
              'client_id': 'kev',
              'nickname': 'Kevin',
              'answers': [],
              'answer': '0',
              'correct': false,
              'round_score': 0,
              'puzzle': oddJson(),
            },
          ],
          'examples': {},
          'eliminated': [],
        },
        nextRoundAt: now.add(const Duration(seconds: 8)),
      ),
    );
    ((results['room'] as Map)['settings'] as Map)['format'] = 'relay';
    h.socket.push(results);
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Add 2 each time.'), findsOneWidget);
    // La réponse de Kevin est lue sur sa propre énigme.
    expect(find.text('Cat'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('IQ room setup offers rounds or relay, like Geography & Nature', (
    tester,
  ) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const IqSetupScreen(mode: IqSetupMode.room));
    expect(find.text('Knockout'), findsNothing);
    await tester.tap(find.text('Relay'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('iq_start')));
    await tester.pump();
    final create = h.socket.sent.lastWhere((m) => m['type'] == 'create_room');
    expect((create['settings'] as Map)['format'], 'relay');
    expect((create['settings'] as Map)['game'], 'iq');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('knockout mode can be played with IQ puzzles', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, EliminationScreen(apiClient: FakeServer().api));
    await tester.tap(find.text('IQ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('elim_iq_penalty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('elim_iq_penalty')));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('invite_friends')),
      200,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite_friends')));
    await tester.pump();
    final create = h.socket.sent.lastWhere((m) => m['type'] == 'create_room');
    final settings = create['settings'] as Map<String, dynamic>;
    expect(settings['format'], 'elimination');
    expect(settings['game'], 'iq');
    expect(settings['iq_penalty'], isTrue);
    expect(settings['strict_spelling'], isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('figure puzzles are drawn and answered by tapping a figure', (
    tester,
  ) async {
    tallPhone(tester);
    Map<String, dynamic> fig(String s, int n) => {
      's': s,
      'c': 0,
      'n': n,
      'f': true,
      'r': 0,
    };
    final puzzle = IqPuzzle.fromJson({
      'id': 'matrix-1-test',
      'kind': 'matrix',
      'level': 1,
      'input': 'choice',
      'prompt': {
        'fr': 'Quelle figure complète la grille ?',
        'en': 'Which figure completes the grid?',
      },
      'choices': {
        'fr': ['A', 'B', 'C', 'D'],
        'en': ['A', 'B', 'C', 'D'],
      },
      'figures': {
        'layout': 'grid',
        'cells': [
          for (final s in ['circle', 'square'])
            for (final n in [1, 2, 3]) fig(s, n),
          fig('star', 1),
          fig('star', 2),
          null,
        ],
        'options': [
          fig('star', 1),
          fig('star', 3),
          fig('circle', 3),
          fig('square', 3),
        ],
      },
      'answer': '1',
      'explanation': {
        'fr': 'Forme par ligne, nombre par colonne.',
        'en': 'Shape by row, number by column.',
      },
    });
    expect(puzzle.figures!.cells, hasLength(9));
    final h = Harness();
    await h.start(
      tester,
      IqSoloScreen(
        rounds: 1,
        duration: 30,
        difficulty: Difficulty.normal,
        scoring: const IqScoring(speedBonus: false),
        puzzles: [puzzle],
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('iq_figure_grid')), findsOneWidget);
    expect(find.text('Matrix'.toUpperCase()), findsOneWidget);
    await tapKey(tester, 'iq_choice_1');
    expect(find.byKey(const Key('iq_answer')), findsOneWidget);
    expect(find.text('Shape by row, number by column.'), findsOneWidget);
    await tapKey(tester, 'iq_next');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('1 right answers out of 1 · 10 points'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('free solo offers IQ and can switch back', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, SoloSetupScreen(apiClient: FakeServer().api));
    final picker = find.byKey(const Key('solo_game_picker'));
    await tester.tap(find.descendant(of: picker, matching: find.text('IQ')));
    await tester.pumpAndSettle();
    expect(find.byType(IqSetupScreen), findsOneWidget);
    expect(find.byType(SoloSetupScreen), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('solo_game_picker')),
        matching: find.text('Geography & Nature'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SoloSetupScreen), findsOneWidget);
  });

  testWidgets('IQ room jokers: 50/50 greys out two wrong choices for me', (
    tester,
  ) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const RoomScreen());
    final now = DateTime.now().toUtc();
    final event = iqRoom(
      roomEvent(
        'round',
        round: {
          'number': 1,
          'letter': '',
          'duration': 30,
          'started_at': now.toIso8601String(),
          'ends_at': now.add(const Duration(seconds: 30)).toIso8601String(),
          'puzzle': oddJson(withAnswer: false),
        },
      ),
    );
    (event['room'] as Map)['prices'] = {
      'iq_fifty': 3,
      'iq_hint': 3,
      'iq_time': 3,
      'iq_skip': 5,
    };
    h.socket.push(event);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.byKey(const Key('iq_joker_fifty')), findsOneWidget);
    expect(find.byKey(const Key('iq_joker_hint')), findsNothing);
    await tapKey(tester, 'iq_joker_fifty');
    expect(h.socket.sent.last, {
      'type': 'iq_joker',
      'round': 1,
      'kind': 'fifty',
    });
    h.socket.push({
      'type': 'iq_joker',
      'round': 1,
      'kind': 'fifty',
      'price': 3,
      'removed': [0, 3],
      'wallet': {
        'coins': 7,
        'coins_gained': 0,
        'points_to_next_coin': 20,
        'level': 1,
      },
    });
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('iq_choice_0')), warnIfMissed: false);
    await tester.pump();
    expect(
      h.socket.sent.last['type'],
      'iq_joker',
      reason: 'removed choices cannot be picked',
    );
    await tapKey(tester, 'iq_choice_2');
    expect(h.socket.sent.last, {
      'type': 'iq_answer',
      'round': 1,
      'answer': '2',
    });
    expect(h.online.wallet?.coins, 7);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an IQ room can be a betting room', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const IqSetupScreen(mode: IqSetupMode.room));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('iq_room_kind')),
        matching: find.text('Bets'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iq_stake')), findsOneWidget);
    await tester.tap(find.byKey(const Key('iq_start')));
    await tester.pump();
    final create = h.socket.sent.lastWhere((m) => m['type'] == 'create_room');
    final settings = create['settings'] as Map<String, dynamic>;
    expect(settings['game'], 'iq');
    expect(settings['kind'], 'bet');
    expect(settings['stake'], greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}
