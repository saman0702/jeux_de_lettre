import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/core/network/realtime_client.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/home/country_picker.dart';
import 'package:letter_battle/features/online/data/room_models.dart';
import 'package:letter_battle/features/online/room_screen.dart';

import 'online_test.dart'
    show FakeSocket, Harness, me, player, pumpFor, roomEvent;

void main() {
  test('language and country travel with the connection', () async {
    final uris = <Uri>[];
    final client = RealtimeClient(
      clientId: me,
      nickname: 'Blaise',
      language: 'en',
      country: 'Ivory Coast',
      pingInterval: null,
      connector: (uri) async {
        uris.add(uri);
        return FakeSocket();
      },
    );
    await client.connect();
    expect(uris.last.queryParameters['language'], 'en');
    expect(uris.last.queryParameters['country'], 'Ivory Coast');

    // Changer de pays reconnecte pour que les autres voient le nouveau drapeau.
    await client.updateIdentity(country: 'France');
    expect(uris, hasLength(2));
    expect(uris.last.queryParameters['country'], 'France');
    client.dispose();
  });

  testWidgets('the country is chosen from a searchable list', (tester) async {
    final h = Harness();
    String? picked;
    await h.start(
      tester,
      Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => CountryButton(
              value: picked,
              onChanged: (c) => setState(() => picked = c),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('country_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('country_search')), 'ivory');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('country_Ivory Coast')));
    await tester.pumpAndSettle();
    expect(picked, 'Ivory Coast');
    expect(find.text('Ivory Coast'), findsOneWidget);
    expect(find.byKey(const Key('country_badge')), findsOneWidget);
  });

  testWidgets('a mixed room shows flags and the languages in play', (
    tester,
  ) async {
    final h = Harness();
    await h.start(tester, const RoomScreen());
    h.socket.push(
      roomEvent(
        'waiting',
        players: [
          {...player(me, 'Blaise'), 'language': 'en', 'country': 'Ivory Coast'},
          {...player('jean', 'Jean'), 'language': 'fr', 'country': 'France'},
        ],
      ),
    );
    await pumpFor(tester);
    expect(find.text('FR + EN: each in their own language'), findsOneWidget);
    expect(find.byKey(const Key('country_badge')), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 1));
  });

  test('each player sees possible answers in their own language', () {
    final results = RoomRoundResults.fromJson({
      'number': 1,
      'letter': 'E',
      'players': [],
      'examples': {'country': 'Espagne'},
      'examples_by_language': {
        'fr': {'country': 'Espagne'},
        'en': {'country': 'Egypt'},
      },
    });
    expect(results.examplesFor('en')[Category.country], 'Egypt');
    expect(results.examplesFor('fr')[Category.country], 'Espagne');
    expect(
      results.examplesFor('es')[Category.country],
      'Espagne',
      reason: 'fallback',
    );
  });
}
