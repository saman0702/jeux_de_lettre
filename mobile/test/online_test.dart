import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/network/realtime_client.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/game/solo_setup_screen.dart';
import 'package:letter_battle/features/home/home_screen.dart';
import 'package:letter_battle/features/online/room_screen.dart';
import 'package:letter_battle/features/online/online_controller.dart';
import 'package:letter_battle/features/online/create_room_screen.dart';
import 'package:letter_battle/features/online/rooms_screen.dart';
import 'package:letter_battle/features/shop/shop_controller.dart';
import 'package:letter_battle/features/wallet/wallet.dart';
import 'package:letter_battle/main.dart';

import 'widget_test.dart' show fakeApi;

const me = 'me-client-id';

/// Faux serveur WebSocket : enregistre ce que l'appli envoie et pousse des
/// événements du serveur.
class FakeSocket implements RealtimeConnection {
  final _incoming = StreamController<String>();
  final List<Map<String, dynamic>> sent = [];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) =>
      sent.add(jsonDecode(message) as Map<String, dynamic>);

  @override
  Future<void> close() async {
    // Sans await : l'appli a déjà annulé son abonnement.
    _incoming.close();
  }

  void push(Map<String, dynamic> event) => _incoming.add(jsonEncode(event));

  List<String> get sentTypes => [for (final m in sent) m['type'] as String];
}

class Harness {
  Harness({String? nickname = 'Blaise'}) {
    settings = AppSettings.inMemory(nickname: nickname, clientId: me);
    feedback = GameFeedback(
      audio: SilentGameAudio(),
      settings: settings,
      ambientMotion: false,
    );
    client = RealtimeClient(
      clientId: me,
      nickname: nickname ?? 'Joueur',
      pingInterval: null,
      connector: (uri) async {
        if (refuseConnections) throw Exception('server unreachable');
        uris.add(uri);
        socket = FakeSocket();
        return socket;
      },
    );
    online = OnlineController(client);
  }

  late final AppSettings settings;
  late final GameFeedback feedback;
  late final RealtimeClient client;
  late final OnlineController online;
  late FakeSocket socket;
  final List<Uri> uris = [];

  /// Simule un serveur injoignable pour les reconnexions.
  bool refuseConnections = false;

  Future<void> start(
    WidgetTester tester,
    Widget home, {
    ShopController? shop,
  }) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(
        feedback: feedback,
        online: online,
        shop: shop,
        home: home,
      ),
    );
    await client.connect();
    socket.push({'type': 'welcome', 'online_count': 7});
    await tester.pumpAndSettle();
  }
}

/// L'écran de salle rafraîchit ses comptes à rebours en continu, il ne se «
/// stabilise » donc jamais : on avance le temps explicitement au lieu
/// d'utiliser pumpAndSettle.
Future<void> pumpFor(
  WidgetTester tester, [
  Duration duration = const Duration(seconds: 2),
]) async {
  for (
    var t = Duration.zero;
    t < duration;
    t += const Duration(milliseconds: 100)
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> player(
  String id,
  String name, {
  bool ready = false,
  int score = 0,
  bool finished = false,
  bool connected = true,
  String? botLevel,
}) => {
  'bot': botLevel != null,
  'bot_level': botLevel,
  'client_id': id,
  'nickname': name,
  'ready': ready,
  'connected': connected,
  'score': score,
  'finished': finished,
  'playing': true,
};

Map<String, dynamic> roomEvent(
  String phase, {
  bool quick = false,
  List<Map<String, dynamic>>? players,
  Map<String, dynamic>? round,
  Map<String, dynamic>? results,
  DateTime? startsAt,
  DateTime? goAt,
  DateTime? nextRoundAt,
}) {
  final now = DateTime.now().toUtc();
  return {
    'type': 'room_state',
    'room': {
      'code': 'X7K92',
      'public': true,
      'quick': quick,
      'host_id': me,
      'phase': phase,
      'settings': {
        'language': 'en',
        'difficulty': 'normal',
        'categories': ['city', 'fruit'],
        'rounds': 5,
        'round_duration': 30,
        'max_players': 8,
      },
      'players': players ?? [player(me, 'Blaise'), player('kev', 'Kevin')],
      'round_number': round == null ? 0 : round['number'],
      'round': round,
      'results': results,
      'starts_at': startsAt?.toIso8601String(),
      'go_at': goAt?.toIso8601String(),
      'next_round_at': nextRoundAt?.toIso8601String(),
      'server_time': now.toIso8601String(),
    },
  };
}

Map<String, dynamic> round1() {
  final now = DateTime.now().toUtc();
  return {
    'number': 1,
    'letter': 'M',
    'duration': 30,
    'started_at': now.toIso8601String(),
    'ends_at': now.add(const Duration(seconds: 30)).toIso8601String(),
  };
}

void main() {
  testWidgets('home shows how many players are online', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));

    expect(find.text('7'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    h.socket.push({'type': 'online_count', 'count': 12});
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(h.uris.single.queryParameters, {
      'client_id': me,
      'nickname': 'Blaise',
    });
  });

  testWidgets('quick match: search, play a round, results and podium', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));

    await tester.tap(find.text('Quick match'));
    await pumpFor(tester);
    expect(h.socket.sent.last, {'type': 'quick_match', 'language': 'en'});
    expect(find.text('Looking for players…'), findsOneWidget);

    final starts = DateTime.now().toUtc().add(const Duration(seconds: 12));
    h.socket.push(roomEvent('waiting', quick: true, startsAt: starts));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Starting in'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Kevin'), findsOneWidget);

    h.socket.push(roomEvent('round', round: round1()));
    await pumpFor(tester);
    expect(find.byKey(const Key('letter')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field_city')), 'Madrid');
    await tester.tap(find.byKey(const Key('key_finish')));
    await tester.pump();
    expect(h.socket.sent.last, {
      'type': 'submit',
      'round': 1,
      'answers': {'city': 'Madrid', 'fruit': ''},
    });

    h.socket.push(
      roomEvent(
        'round',
        round: round1(),
        players: [player(me, 'Blaise', finished: true), player('kev', 'Kevin')],
      ),
    );
    await pumpFor(tester);
    expect(find.text('Answers sent!'), findsOneWidget);

    Map<String, dynamic> result(
      String id,
      String name,
      int points,
      String city,
    ) => {
      'client_id': id,
      'nickname': name,
      'round_score': points,
      'elapsed_ms': 4000,
      'answers': [
        {
          'category': 'city',
          'value': city,
          'status': points > 0 ? 'valid' : 'not_found',
          'points': points,
          'matched_value': points > 0 ? city : null,
        },
      ],
    };
    h.socket.push(
      roomEvent(
        'results',
        players: [player(me, 'Blaise', score: 10), player('kev', 'Kevin')],
        results: {
          'number': 1,
          'letter': 'M',
          'players': [
            result(me, 'Blaise', 10, 'Madrid'),
            result('kev', 'Kevin', 0, 'Mxx'),
          ],
        },
        nextRoundAt: DateTime.now().toUtc().add(const Duration(seconds: 8)),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.text('Your answers'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Kevin found: Melun'), findsNothing);
    expect(find.textContaining('Next round in'), findsOneWidget);
    expect(h.feedback.audio, isA<SilentGameAudio>());
    expect(
      (h.feedback.audio as SilentGameAudio).played,
      containsAllInOrder([Sfx.valid, Sfx.points]),
    );

    h.socket.push(
      roomEvent(
        'finished',
        players: [
          player(me, 'Blaise', score: 42),
          player('kev', 'Kevin', score: 30),
        ],
      ),
    );
    await pumpFor(tester, const Duration(seconds: 4));
    expect(find.text('PODIUM'), findsOneWidget);
    expect(find.text('42 pts'), findsOneWidget);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();
    expect(h.socket.sent.last, {'type': 'set_ready', 'ready': true});
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('first online game asks for a nickname and reconnects with it', (
    tester,
  ) async {
    final h = Harness(nickname: null);
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));

    await tester.tap(find.text('Rooms'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nickname_field')), 'Arnaud');
    await tester.tap(find.text("LET'S GO!"));
    await tester.pumpAndSettle();

    expect(h.settings.nickname, 'Arnaud');
    expect(h.uris.last.queryParameters['nickname'], 'Arnaud');
    expect(find.byType(RoomsScreen), findsOneWidget);
  });

  testWidgets('rooms screen lists public rooms and joins one', (tester) async {
    final h = Harness();
    await h.start(tester, const RoomsScreen());
    expect(h.socket.sent.first, {'type': 'subscribe_rooms', 'language': 'en'});

    h.socket.push({
      'type': 'room_list',
      'rooms': [
        {
          'code': 'AB234',
          'quick': false,
          'host': 'Serge',
          'players': 3,
          'max_players': 8,
          'language': 'en',
          'difficulty': 'normal',
          'rounds': 10,
          'round_duration': 45,
        },
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text("Serge's room"), findsOneWidget);
    expect(find.text('3/8'), findsOneWidget);

    await tester.tap(find.text("Serge's room"));
    await tester.pump();
    expect(h.socket.sent.last, {'type': 'join_room', 'code': 'AB234'});

    h.socket.push(roomEvent('waiting'));
    await pumpFor(tester);
    await tester.tap(find.byKey(const Key('ready_button')));
    await tester.pump();
    expect(h.socket.sent.last, {'type': 'set_ready', 'ready': true});
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('room errors are shown and bring the player back', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, const RoomsScreen());

    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code_field')), 'zzzzz');
    await tester.tap(find.text('Join'));
    await pumpFor(tester);
    expect(h.socket.sent.last, {'type': 'join_room', 'code': 'ZZZZZ'});

    h.socket.push({'type': 'error', 'code': 'room_not_found'});
    await pumpFor(tester);
    expect(find.text('Room not found.'), findsOneWidget);
    expect(find.byType(RoomsScreen), findsOneWidget);
  });

  testWidgets('solo against bots starts an online game with computer players', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, SoloSetupScreen(apiClient: fakeApi(healthy: true)));

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('2'), 150, scrollable: list);
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bot level'),
      150,
      scrollable: list,
    );
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard').last);
    await tester.tap(find.text('PLAY'));
    await pumpFor(tester);

    final create = h.socket.sent.last;
    expect(create['type'], 'create_room');
    expect(create['bots'], {'count': 2, 'level': 'hard'});
    expect((create['settings'] as Map)['max_players'], 3);
    expect(find.byType(RoomScreen), findsOneWidget);
  });

  testWidgets('host adds and removes bots in the lobby', (tester) async {
    final h = Harness();
    await h.start(tester, const RoomsScreen());
    await tester.tap(find.text('Join with a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code_field')), 'X7K92');
    await tester.tap(find.text('Join'));
    await pumpFor(tester);

    h.socket.push(
      roomEvent(
        'waiting',
        players: [
          player(me, 'Blaise'),
          player('bot-1', 'Robo-Léa', ready: true, botLevel: 'easy'),
        ],
      ),
    );
    await pumpFor(tester);
    expect(find.text('Robo-Léa'), findsOneWidget);
    // Avec un bot dans la salle, c'est la musique « bots ».
    expect((h.feedback.audio as SilentGameAudio).mood, MusicMood.bots);

    await tester.tap(find.byKey(const Key('add_bot_button')));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Easy'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(h.socket.sent.last, {'type': 'add_bot', 'level': 'easy'});

    await tester.tap(find.byKey(const Key('remove_bot-1')));
    await tester.pump();
    expect(h.socket.sent.last, {'type': 'remove_bot', 'client_id': 'bot-1'});
    await pumpFor(tester, const Duration(seconds: 1));
  });

  testWidgets('lonely quick match announces the bots', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    await tester.tap(find.text('Quick match'));
    await pumpFor(tester);
    h.socket.push(
      roomEvent(
        'waiting',
        quick: true,
        players: [player(me, 'Blaise', ready: true)],
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    h.socket.push({'type': 'notice', 'kind': 'bots_joined', 'nickname': ''});
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Nobody online: bots are joining you!'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 3));
  });

  testWidgets('hints in a room go through the socket', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    await tester.tap(find.text('Quick match'));
    await pumpFor(tester);
    h.socket.push(
      roomEvent(
        'round',
        round: round1(),
        players: [
          {...player(me, 'Blaise'), 'hints_left': 3},
          player('kev', 'Kevin'),
        ],
      ),
    );
    await pumpFor(tester);

    await tester.tap(find.byKey(const Key('hint_fruit')));
    await tester.pump();
    expect(h.socket.sent.last, {
      'type': 'hint',
      'round': 1,
      'category': 'fruit',
    });
    h.socket.push({
      'type': 'hint',
      'round': 1,
      'category': 'fruit',
      'hints_left': 2,
      'options': ['Mangue', 'Madrid', 'Maroc', 'Mouton'],
    });
    await pumpFor(tester, const Duration(seconds: 1));

    await tester.tap(find.text('Maroc'));
    await tester.pump();
    expect(h.socket.sent.last, {
      'type': 'hint_pick',
      'round': 1,
      'category': 'fruit',
      'choice': 'Maroc',
    });
    h.socket.push({
      'type': 'hint_result',
      'round': 1,
      'category': 'fruit',
      'correct': false,
      'answer': 'Mangue',
    });
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.byKey(const Key('hint_fruit')), findsNothing);
    expect(
      find.byIcon(Icons.cancel_rounded),
      findsOneWidget,
      reason: 'wrong pick shown in red',
    );
  });

  testWidgets('leaving an online game warns the server', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    await tester.tap(find.text('Quick match'));
    await pumpFor(tester);
    h.socket.push(roomEvent('round', round: round1()));
    await pumpFor(tester);

    await tester.tap(find.byKey(const Key('quit_button')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('dialog_confirm')));
    await pumpFor(tester);

    expect(h.socket.sent.last, {'type': 'leave_room'});
    expect(find.byType(RoomScreen), findsNothing);
    expect(find.text('Quick match'), findsOneWidget);
  });

  testWidgets('online results show what others found where I missed', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    await tester.tap(find.text('Quick match'));
    await pumpFor(tester);

    Map<String, dynamic> answer(String category, String value, bool valid) => {
      'category': category,
      'value': value,
      'status': valid ? 'valid' : 'not_found',
      'points': valid ? 10 : 0,
      'matched_value': valid ? value : null,
    };
    h.socket.push(
      roomEvent(
        'results',
        players: [player(me, 'Blaise'), player('flo', 'Flore', score: 10)],
        results: {
          'number': 1,
          'letter': 'M',
          'examples': {'city': 'Madrid'},
          'players': [
            {
              'client_id': me,
              'nickname': 'Blaise',
              'round_score': 0,
              'elapsed_ms': 4000,
              'answers': [
                answer('city', 'Mxx', false),
                answer('fruit', '', false),
              ],
            },
            {
              'client_id': 'flo',
              'nickname': 'Flore',
              'round_score': 10,
              'elapsed_ms': 3000,
              'answers': [
                answer('city', 'Mzz', false),
                answer('fruit', 'Melon', true),
              ],
            },
          ],
        },
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    expect(find.text('Flore found: Melon'), findsOneWidget);
    expect(
      find.text('Possible answer: Madrid'),
      findsOneWidget,
      reason: 'personne n\'a trouvé la ville',
    );
  });

  testWidgets('home shows the coins and celebrates a gain', (tester) async {
    final h = Harness();
    await h.start(tester, HomeScreen(apiClient: fakeApi(healthy: true)));
    h.socket.push({
      'type': 'wallet',
      'coins': 4,
      'coins_gained': 0,
      'points_to_next_coin': 10,
    });
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('coin_counter')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('coin_gain')), findsNothing);

    h.socket.push({
      'type': 'wallet',
      'coins': 5,
      'coins_gained': 1,
      'points_to_next_coin': 20,
    });
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const Key('coin_gain')), findsOneWidget);
    expect(find.text('+1 coin'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.byKey(const Key('coin_gain')), findsNothing);
    expect(h.online.wallet!.coins, 5);
  });

  testWidgets('creating a betting room sends the stake', (tester) async {
    final h = Harness();
    await h.start(tester, const CreateRoomScreen());
    h.online.applyWallet(const WalletSnapshot(coins: 30));
    await tester.pump();

    await tester.tap(find.text('Bets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your balance: 30'), findsOneWidget);
    await tester.tap(find.text('CREATE'));
    await tester.pump();
    final settings = h.socket.sent.last['settings'] as Map<String, dynamic>;
    expect((settings['kind'], settings['stake']), ('bet', 25));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a betting room shows the pot, then what I won', (tester) async {
    final h = Harness();
    await h.start(tester, const RoomScreen());
    Map<String, dynamic> bet(Map<String, dynamic> event) {
      final room = event['room'] as Map<String, dynamic>;
      (room['settings'] as Map<String, dynamic>)
        ..['kind'] = 'bet'
        ..['stake'] = 10;
      return event;
    }

    h.socket.push(bet(roomEvent('waiting')));
    await pumpFor(tester);
    final audio = h.feedback.audio as SilentGameAudio;
    expect((audio.mood, audio.quiet), (MusicMood.room, false));
    expect(find.text('Stake 10 · Pot: 20'), findsOneWidget);
    expect(find.byKey(const Key('add_bot_button')), findsNothing);

    final finished = bet(
      roomEvent(
        'finished',
        players: [
          player(me, 'Blaise', score: 30),
          player('kev', 'Kevin', score: 10),
        ],
      ),
    );
    (finished['room'] as Map<String, dynamic>)
      ..['pot'] = 20
      ..['winnings'] = {me: 20};
    h.socket.push(finished);
    await pumpFor(tester, const Duration(seconds: 3));
    expect(find.text('You win 20 coins!'), findsOneWidget);
  });
}
