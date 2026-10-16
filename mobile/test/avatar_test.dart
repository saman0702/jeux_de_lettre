import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/avatar/avatar_screen.dart';
import 'package:letter_battle/features/avatar/drawn_avatar.dart';
import 'package:letter_battle/features/online/room_screen.dart';

import 'online_test.dart' show Harness, me, player, pumpFor, roomEvent;

/// Faux serveur de profils : enregistre les requêtes reçues.
class FakeProfiles {
  final List<http.Request> requests = [];

  late final api = ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      final photo = request.url.path.endsWith('/avatar');
      final preset = photo
          ? 2
          : (jsonDecode(request.body) as Map)['avatar_preset'] as int;
      return http.Response(
        jsonEncode({
          'client_id': me,
          'nickname': 'Blaise',
          'coins': 0,
          'total_points': 0,
          'points_to_next_coin': 20,
          'avatar_preset': preset,
          'avatar_url': photo ? '/media/avatars/$me-1234.png' : null,
        }),
        200,
      );
    }),
  );
}

void main() {
  testWidgets('choosing a drawn character saves it on the profile', (
    tester,
  ) async {
    final h = Harness();
    final server = FakeProfiles();
    await h.start(tester, AvatarScreen(apiClient: server.api));
    expect(find.byType(DrawnAvatar), findsNWidgets(drawnAvatarCount + 1));

    await tester.tap(find.byKey(const Key('preset_7')));
    await tester.pumpAndSettle();
    expect(server.requests.single.method, 'PUT');
    expect(server.requests.single.url.path, '/api/v1/profiles/$me');
    expect(jsonDecode(server.requests.single.body), {'avatar_preset': 7});
    expect(h.online.avatarPreset, 7);
    expect(find.text('Avatar updated!'), findsOneWidget);
  });

  testWidgets('a photo is sent to be turned into a drawing', (tester) async {
    final h = Harness();
    final server = FakeProfiles();
    final sources = <ImageSource>[];
    await h.start(
      tester,
      AvatarScreen(
        apiClient: server.api,
        pickPhoto: (source) async {
          sources.add(source);
          return (bytes: [1, 2, 3], name: 'selfie.jpg');
        },
      ),
    );

    await tester.tap(find.byKey(const Key('avatar_camera')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(sources, [ImageSource.camera]);
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/profiles/$me/avatar');
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    expect(request.body, contains('name="photo"; filename="selfie.jpg"'));
    expect(h.online.avatarUrl, '/media/avatars/$me-1234.png');
  });

  testWidgets('a player photo can be reported from the lobby', (tester) async {
    final h = Harness();
    await h.start(tester, const RoomScreen());
    final event = roomEvent(
      'waiting',
      players: [
        player(me, 'Blaise'),
        {...player('kev', 'Kevin'), 'avatar_url': '/media/avatars/kev.png'},
      ],
    );
    h.socket.push(event);
    await pumpFor(tester);
    expect(find.byKey(Key('report_$me')), findsNothing);

    await tester.tap(find.byKey(const Key('report_kev')));
    await pumpFor(tester);
    expect(find.text('REPORT THIS PHOTO?'), findsOneWidget);
    await tester.tap(find.text('REPORT'));
    await pumpFor(tester);
    expect(h.socket.sent.last, {'type': 'report_player', 'client_id': 'kev'});
    expect(find.text('Thanks, report sent.'), findsOneWidget);
  });
}
