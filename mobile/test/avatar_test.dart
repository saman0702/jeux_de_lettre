import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/avatar/avatar_screen.dart';
import 'package:letter_battle/features/avatar/avatar_sync.dart';
import 'package:letter_battle/features/avatar/drawn_avatar.dart';
import 'package:letter_battle/features/online/room_screen.dart';

import 'online_test.dart' show Harness, me, player, pumpFor, roomEvent;

/// Faux serveur de profils : enregistre les requêtes reçues.
class FakeProfiles {
  final List<http.Request> requests = [];

  /// Simule un serveur injoignable.
  bool down = false;

  late final api = ApiClient(
    client: MockClient((request) async {
      if (down) throw Exception('offline');
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

  testWidgets('a character chosen without the server is kept, then sent', (
    tester,
  ) async {
    final h = Harness();
    final server = FakeProfiles()..down = true;
    await h.start(tester, AvatarScreen(apiClient: server.api));

    await tester.tap(find.byKey(const Key('preset_4')));
    await tester.pumpAndSettle();
    expect(h.online.avatarPreset, 4, reason: 'shown right away');
    expect(h.settings.avatarPreset, 4);
    expect(h.settings.avatarPending, isTrue);
    expect(find.textContaining('as soon as you are online'), findsOneWidget);

    // À la reconnexion, le choix part au serveur.
    server.down = false;
    final sync = AvatarSync(
      settings: h.settings,
      online: h.online,
      api: server.api,
    );
    h.socket.close();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(jsonDecode(server.requests.last.body), {'avatar_preset': 4});
    expect(h.settings.avatarPending, isFalse);
    sync.dispose();
  });

  testWidgets('the photo buttons explain why they need a connection', (
    tester,
  ) async {
    final h = Harness();
    var opened = false;
    await h.start(
      tester,
      AvatarScreen(
        apiClient: FakeProfiles().api,
        pickPhoto: (_) async {
          opened = true;
          return null;
        },
      ),
    );
    h.refuseConnections = true;
    h.socket.close();
    await tester.pumpAndSettle();
    expect(h.online.isOnline, isFalse);
    await tester.tap(find.byKey(const Key('avatar_gallery')));
    await tester.pumpAndSettle();
    expect(opened, isFalse);
    expect(find.textContaining('Go online to use a photo'), findsOneWidget);
    // Le serveur revient : plus de reconnexion en attente à la fin du test.
    h.refuseConnections = false;
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a refused camera permission is reported', (tester) async {
    final h = Harness();
    await h.start(
      tester,
      AvatarScreen(
        apiClient: FakeProfiles().api,
        pickPhoto: (_) async => throw Exception('camera_access_denied'),
      ),
    );
    await tester.tap(find.byKey(const Key('avatar_camera')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check the app permissions'), findsOneWidget);
    expect(h.online.isOnline, isTrue);
  });
}
