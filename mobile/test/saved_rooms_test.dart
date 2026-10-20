import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/online/room_history.dart';
import 'package:letter_battle/features/online/widgets/salon_social.dart';

import 'online_test.dart' show Harness, me, player, pumpFor, roomEvent;

final _now = DateTime.now().toUtc().toIso8601String();

Map<String, dynamic> summary(
  String code, {
  bool mine = true,
  bool open = false,
}) => {
  'code': code,
  'public': !mine,
  'creator': 'Flore',
  'language': 'en',
  'format': 'rounds',
  'kind': 'classic',
  'members': 3,
  'mine': mine,
  'open': open,
  'players_now': open ? 2 : 0,
  'last_activity_at': _now,
};

ApiClient savedApi() => ApiClient(
  client: MockClient((request) async {
    final path = request.url.path;
    http.Response json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (path == '/api/v1/rooms/mine') return json([summary('AB123')]);
    if (path == '/api/v1/rooms/public') {
      return json([
        summary('AB123', mine: true),
        summary('PUB99', mine: false, open: true),
      ]);
    }
    if (path == '/api/v1/rooms/AB123/history') {
      return json({
        'room': summary('AB123'),
        'games': [
          {
            'finished_at': _now,
            'format': 'rounds',
            'rounds': 5,
            'ranking': [
              {
                'client_id': 'kev',
                'nickname': 'Kevin',
                'score': 40,
                'bot': false,
              },
              {
                'client_id': me,
                'nickname': 'Blaise',
                'score': 25,
                'bot': false,
              },
            ],
          },
        ],
        'group': [
          {
            'client_id': 'kev',
            'nickname': 'Kevin',
            'text': 'Bien joué @Blaise',
            'mentions': [me],
            'to': null,
            'at': _now,
          },
        ],
        'private': [
          {
            'client_id': 'kev',
            'nickname': 'Kevin',
            'text': 'Revanche ce soir ?',
            'mentions': [],
            'to': me,
            'at': _now,
          },
        ],
      });
    }
    return http.Response('{"detail":"not_found"}', 404);
  }),
);

void main() {
  testWidgets('my rooms and other public rooms are listed', (tester) async {
    final h = Harness();
    final opened = <String>[];
    await h.start(
      tester,
      Scaffold(
        body: ListView(
          children: [
            SavedRoomsSection(apiClient: savedApi(), onOpen: opened.add),
          ],
        ),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('My rooms'), findsOneWidget);
    expect(find.text('All public rooms'), findsOneWidget);
    expect(
      find.byKey(const Key('saved_room_AB123')),
      findsOneWidget,
      reason: 'listed once',
    );
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('2 inside'), findsOneWidget);
    await tester.tap(find.byKey(const Key('saved_room_AB123')));
    expect(opened, ['AB123']);
  });

  testWidgets('a room history shows games, the group chat and private talks', (
    tester,
  ) async {
    final h = Harness();
    await h.start(
      tester,
      RoomHistoryScreen(code: 'AB123', apiClient: savedApi()),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Kevin'), findsOneWidget);
    expect(find.text('40 pts'), findsOneWidget);

    await tester.tap(find.text('Group'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Bien joué @Blaise'), findsOneWidget);

    await tester.tap(find.text('Private'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('private_kev')));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Revanche ce soir ?'), findsOneWidget);
    expect(find.text('Join the room to reply.'), findsOneWidget);
  });

  testWidgets('in the room, private messages are sent and received', (
    tester,
  ) async {
    final h = Harness();
    await h.start(
      tester,
      const PrivateChatScreen(
        code: 'X7K92',
        otherId: 'kev',
        otherName: 'Kevin',
      ),
    );
    final event = roomEvent('waiting');
    final room = event['room'] as Map<String, dynamic>;
    room['saved'] = true;
    room['players'] = [
      {...player(me, 'Blaise'), 'chat_unlocked': true},
      player('kev', 'Kevin'),
    ];
    h.socket.push(event);
    await pumpFor(tester, const Duration(milliseconds: 300));

    await tester.enterText(
      find.byKey(const Key('private_text')),
      'Salut Kevin',
    );
    await tester.tap(find.byKey(const Key('private_send')));
    await tester.pump();
    expect(h.socket.sent.last, {
      'type': 'dm',
      'to': 'kev',
      'text': 'Salut Kevin',
    });

    h.socket.push({
      'type': 'dm',
      'room': 'X7K92',
      'message': {
        'client_id': 'kev',
        'nickname': 'Kevin',
        'text': 'Salut !',
        'mentions': [],
        'to': me,
        'at': _now,
      },
    });
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Salut !'), findsOneWidget);
  });

  testWidgets('the group chat is free and a name tap tags the player', (
    tester,
  ) async {
    final h = Harness();
    final event = roomEvent('waiting');
    final room = event['room'] as Map<String, dynamic>;
    room['saved'] = true;
    room['chat'] = [
      {
        'client_id': 'kev',
        'nickname': 'Kevin',
        'text': 'Prêt @Blaise ?',
        'mentions': [me],
        'at': _now,
      },
    ];
    await h.start(
      tester,
      Scaffold(
        body: ListenableBuilder(
          listenable: h.online,
          builder: (_, _) => RoomChatPanel(online: h.online),
        ),
      ),
    );
    h.socket.push(event);
    await pumpFor(tester, const Duration(milliseconds: 300));

    // Pas besoin de débloquer pour écrire dans le groupe.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const Key('chat_private')), findsOneWidget);
    await tester.tapAt(
      tester.getTopLeft(find.textContaining('Kevin: ')) + const Offset(8, 8),
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '@Kevin ');
  });
}
