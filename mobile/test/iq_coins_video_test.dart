import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/iq/iq_models.dart';
import 'package:letter_battle/features/iq/iq_solo_screen.dart';
import 'package:letter_battle/features/perks/perks_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iq_test.dart' show sequenceJson, tallPhone, tapKey;
import 'online_test.dart' show Harness, pumpFor;
import 'perks_test.dart' show FakeAds, FakePerksServer;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Map<String, dynamic> game({List<String> used = const []}) => {
    'id': 'g1',
    'mode': 'solo',
    'number': 1,
    'total': 1,
    'duration': 30,
    'extra_seconds': used.contains('time') ? 15 : 0,
    'score': 0,
    'jokers_used': used,
    'joker_prices': {'fifty': 3, 'hint': 3, 'time': 3, 'skip': 5},
    'puzzle': sequenceJson(withAnswer: false),
  };

  Future<(Harness, List<String>, FakeAds)> open(
    WidgetTester tester, {
    required bool rewardedAds,
  }) async {
    final calls = <String>[];
    var coins = 1;
    final perksServer = FakePerksServer(
      features: {'rewarded_ads': rewardedAds, 'rewarded_ad_coins': 5},
    )..coins = coins;
    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        calls.add(path);
        http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        return switch (path) {
          '/api/v1/iq/solo' => json(game()),
          '/api/v1/iq/sessions/g1/ad-break' => json(game()),
          '/api/v1/iq/sessions/g1/ad-break/end' => json({
            ...game(),
            'paused_seconds': 12,
          }),
          // Avant la vidéo : 1 pièce ; après : 6 (la vidéo en rapporte 5).
          '/api/v1/iq/sessions/g1/joker' =>
            perksServer.coins < 3
                ? json({'detail': 'not_enough_coins'}, 402)
                : json({
                    'kind': 'time',
                    'price': 3,
                    'extra_seconds': 15,
                    'wallet': {
                      'coins': coins = perksServer.coins - 3,
                      'coins_gained': 0,
                      'points_to_next_coin': 20,
                      'level': 1,
                    },
                    'game': game(used: ['time']),
                  }),
          _ => json(<String, dynamic>{}),
        };
      }),
    );
    final h = Harness();
    final ads = FakeAds();
    final perks = PerksController(
      api: perksServer.api,
      online: h.online,
      ads: ads,
      pollDelay: const Duration(milliseconds: 10),
    );
    await perks.load();
    tallPhone(tester);
    await h.start(
      tester,
      // Partie chronométrée (30 s) : le joker +15 s est proposé.
      IqSoloScreen(
        rounds: 1,
        duration: 30,
        difficulty: Difficulty.normal,
        scoring: const IqScoring(),
        apiClient: api,
      ),
      perks: perks,
    );
    await pumpFor(tester, const Duration(milliseconds: 600));
    return (h, calls, ads);
  }

  testWidgets(
    'not enough coins for a joker: a video pauses the clock, then the joker is taken',
    (tester) async {
      final (h, calls, ads) = await open(tester, rewardedAds: true);
      await tapKey(tester, 'iq_joker_time');
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(calls, contains('/api/v1/iq/sessions/g1/ad-break'));
      expect(find.textContaining('This joker costs 3 coins'), findsOneWidget);
      expect(find.text('VIDEO (+5)'), findsWidgets);
      await tester.tap(find.byKey(const Key('dialog_confirm')));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(ads.rewarded, 1);
      expect(calls, contains('/api/v1/iq/sessions/g1/ad-break/end'));
      expect(
        calls.where((c) => c == '/api/v1/iq/sessions/g1/joker'),
        hasLength(2),
        reason: 'joker retried once the coins arrived',
      );
      expect(h.online.wallet?.coins, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('declining the video resumes the clock and takes nothing', (
    tester,
  ) async {
    final (_, calls, ads) = await open(tester, rewardedAds: true);
    await tapKey(tester, 'iq_joker_time');
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('dialog_cancel')));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(ads.rewarded, 0);
    expect(calls, contains('/api/v1/iq/sessions/g1/ad-break/end'));
    expect(
      calls.where((c) => c == '/api/v1/iq/sessions/g1/joker'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without rewarded ads, only the not-enough-coins message shows', (
    tester,
  ) async {
    final (_, calls, _) = await open(tester, rewardedAds: false);
    await tapKey(tester, 'iq_joker_time');
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.textContaining('This joker costs 3 coins'), findsNothing);
    expect(calls, isNot(contains('/api/v1/iq/sessions/g1/ad-break')));
    await tester.pumpWidget(const SizedBox());
  });
}
