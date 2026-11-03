import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/home/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'online_test.dart' show Harness, me;

void main() {
  test('erasing the account keeps device settings, drops player data', () async {
    SharedPreferences.setMockInitialValues({
      'settings.sound': true,
      'settings.language': 'fr',
      'player.client_id': 'old-id-123456',
      'player.client_token': 'old-token-0123456789',
      'player.nickname': 'Blaise',
      'career.stars': '{"1":3}',
    });
    final settings = await AppSettings.load();
    await settings.eraseAccountData();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'settings.sound', 'settings.language'});
    final fresh = await AppSettings.load();
    expect(fresh.clientId, isNot('old-id-123456'), reason: 'a new player next time');
    expect(fresh.nickname, isNull);
  });

  testWidgets('deleting my account asks first, then erases it on the server', (tester) async {
    final calls = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        return http.Response('{"ok": true}', 200);
      }),
    );
    final h = Harness();
    await h.start(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => deleteMyAccount(context, api: api),
            child: const Text('delete'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    // Annuler : rien n'est supprimé.
    await tester.tap(find.text('Cancel').first);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE').first);
    await tester.pumpAndSettle();
    expect(calls, ['DELETE /api/v1/profiles/$me']);
    expect(find.textContaining('Account deleted'), findsOneWidget);
  });
}
