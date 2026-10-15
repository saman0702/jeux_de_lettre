import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:letter_battle/core/audio/game_audio.dart';
import 'package:letter_battle/core/feedback/game_feedback.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/core/settings/app_settings.dart';
import 'package:letter_battle/features/home/home_screen.dart';
import 'package:letter_battle/main.dart';

ApiClient fakeApi({required bool healthy}) => ApiClient(
  client: MockClient(
    (_) async => http.Response(
      healthy ? '{"status":"ok"}' : '{"status":"degraded"}',
      200,
    ),
  ),
);

void main() {
  testWidgets('home shows modes and online status in French', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    await tester.pumpWidget(
      LetterBattleApp(home: HomeScreen(apiClient: fakeApi(healthy: true))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('Partie rapide'), findsOneWidget);
    expect(find.text('Serveur connecté'), findsOneWidget);
  });

  testWidgets('menu music plays on the home screen and can be turned off', (
    tester,
  ) async {
    final audio = SilentGameAudio();
    final feedback = GameFeedback(
      audio: audio,
      settings: AppSettings.inMemory(),
      ambientMotion: false,
    );
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(
        feedback: feedback,
        home: HomeScreen(apiClient: fakeApi(healthy: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(audio.musicPlaying, isTrue);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setting_Music')));
    await tester.pumpAndSettle();

    expect(feedback.settings.music, isFalse);
    expect(audio.musicPlaying, isFalse);
  });

  testWidgets('home is translated to English', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(home: HomeScreen(apiClient: fakeApi(healthy: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick match'), findsOneWidget);
    expect(find.text('Server unreachable'), findsOneWidget);
  });
}
