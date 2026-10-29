import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/core/network/realtime_client.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'online_test.dart' show FakeSocket;

void main() {
  test('the secret token is created once and kept', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await AppSettings.load();
    final again = await AppSettings.load();
    expect(first.clientToken, hasLength(48));
    expect(again.clientToken, first.clientToken);
    expect(first.clientToken, isNot(first.clientId));
  });

  test('sound effects are off on a fresh install', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    expect(settings.sound, isFalse);
    expect(settings.music, isTrue, reason: 'only the sound effects change');
  });

  test('every API request carries the secret token', () async {
    final seen = <String?>[];
    final api = ApiClient(
      client: MockClient((request) async {
        seen.add(request.headers['X-Client-Token']);
        return http.Response('{}', 200);
      }),
    );
    ApiClient.clientToken = 'secret-token-0123456789';
    addTearDown(() => ApiClient.clientToken = null);
    await api.getJson('/api/v1/profiles/abc12345');
    await api.postJson('/api/v1/profiles/abc12345/daily-bonus');
    await api.putJson('/api/v1/profiles/abc12345', {'nickname': 'A'});
    expect(seen, everyElement('secret-token-0123456789'));
  });

  test(
    'the live connection sends the token, the id stays the public one',
    () async {
      final uris = <Uri>[];
      final client = RealtimeClient(
        clientId: 'public-id-1234',
        token: 'secret-token-0123456789',
        nickname: 'Blaise',
        pingInterval: null,
        connector: (uri) async {
          uris.add(uri);
          return FakeSocket();
        },
      );
      await client.connect();
      expect(uris.single.queryParameters['client_id'], 'public-id-1234');
      expect(uris.single.queryParameters['token'], 'secret-token-0123456789');
      client.dispose();
    },
  );
}
