import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:letter_battle/core/network/api_client.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/game/offline/normalization.dart';
import 'package:letter_battle/features/game/offline/offline_dictionary.dart';
import 'package:letter_battle/features/game/offline/offline_engine.dart';
import 'package:letter_battle/features/game/solo_game_screen.dart';
import 'package:letter_battle/features/game/solo_setup_screen.dart';
import 'package:letter_battle/main.dart';

import 'solo_game_test.dart' show testFeedback;

const settings = SoloGameSettings(language: 'fr', rounds: 5, roundDuration: 30);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OfflineDictionary dictionary;

  setUpAll(() async {
    dictionary = await OfflineDictionary.load();
  });

  test('normalizes typed answers exactly like the server', () {
    final cases = jsonDecode(
      File('test/fixtures/normalize_cases.json').readAsStringSync(),
    ) as List;
    final mismatches = [
      for (final c in cases)
        if (dictionary.normalizer.normalize(c[0] as String) != c[1])
          '${c[0]} -> ${dictionary.normalizer.normalize(c[0] as String)} (server: ${c[1]})',
    ];
    expect(cases.length, greaterThan(300));
    expect(mismatches, isEmpty);
  });

  group('validation matches the server', () {
    OfflineSoloBackend engine() => OfflineSoloBackend(dictionary);
    final cases = <(Category, String, String, String, AnswerStatus)>[
      (Category.animal, 'fr', 'M', 'Mouton', AnswerStatus.valid),
      (Category.animal, 'fr', 'E', 'ÉLÉPHANT', AnswerStatus.valid),
      (Category.animal, 'fr', 'E', "  l'éléphant ", AnswerStatus.valid),
      (Category.fruit, 'fr', 'M', 'mangues', AnswerStatus.valid),
      (Category.animal, 'fr', 'M', 'Chat', AnswerStatus.wrongLetter),
      (Category.country, 'fr', 'M', 'Marseille', AnswerStatus.notFound),
      (Category.animal, 'en', 'M', 'Mouton', AnswerStatus.notFound),
      (Category.animal, 'en', 'S', 'Sheep', AnswerStatus.valid),
      (Category.city, 'en', 'M', 'Mbandaka', AnswerStatus.valid),
      (Category.city, 'fr', 'H', 'le havre', AnswerStatus.valid),
      (Category.city, 'fr', 'A', 'Abidjan', AnswerStatus.valid),
      (Category.country, 'fr', 'C', "cote d'ivoire", AnswerStatus.valid),
      (Category.country, 'fr', 'R', 'RDC', AnswerStatus.valid),
      (Category.fruit, 'fr', 'K', 'kiwi', AnswerStatus.valid),
      (Category.city, 'fr', 'M', '', AnswerStatus.empty),
    ];
    for (final (category, language, letter, raw, status) in cases) {
      test('$raw ($category, $language, $letter) is ${status.name}', () {
        expect(engine().validate(category, language, letter, raw).$1, status);
      });
    }
  });

  test('hard letters are only drawn in hard mode and never twice', () async {
    final engine = OfflineSoloBackend(dictionary, random: Random(1));
    final game = await engine.createGame(settings);
    final letters = <String>[];
    for (var i = 0; i < 5; i++) {
      letters.add((await engine.startRound(game.id)).letter);
      await engine.submit(game.id, i + 1, {});
    }
    expect(letters.toSet().length, 5);
    expect(letters.any((l) => OfflineRules.hardLetters.contains(l)), isFalse);
  });

  test(
    'a round is scored like on the server, late answers score zero',
    () async {
      var now = DateTime(2026, 1, 1, 12);
      final engine = OfflineSoloBackend(dictionary, now: () => now);
      final game = await engine.createGame(settings);
      final round = await engine.startRound(game.id);
      final (result, after) = await engine.submit(game.id, 1, {
        Category.country: 'France',
      });

      final country = result.answers.firstWhere(
        (a) => a.category == Category.country,
      );
      expect(
        country.status,
        round.letter == 'F' ? AnswerStatus.valid : AnswerStatus.wrongLetter,
      );
      expect(after.roundsPlayed, 1);

      await engine.startRound(game.id);
      now = now.add(const Duration(seconds: 60));
      final (late, _) = await engine.submit(game.id, 2, {
        Category.city: 'Paris',
      });
      expect(late.answers.map((a) => a.status).toSet(), {AnswerStatus.late});
    },
  );

  test('hints offer one valid word among four, three per game', () async {
    final engine = OfflineSoloBackend(dictionary, random: Random(4));
    final game = await engine.createGame(settings);
    final round = await engine.startRound(game.id);

    for (final category in [
      Category.animal,
      Category.fruit,
      Category.country,
    ]) {
      final hint = await engine.requestHint(game.id, round.number, category);
      expect(hint.options.length, 4);
      final valid = hint.options
          .where(
            (o) =>
                engine.validate(category, 'fr', round.letter, o).$1 ==
                AnswerStatus.valid,
          )
          .toList();
      expect(
        valid.length,
        1,
        reason: '$category ${round.letter}: ${hint.options}',
      );
      expect(
        hint.options.every(
          (o) =>
              Normalizer.firstLetter(dictionary.normalizer.normalize(o)) ==
              round.letter,
        ),
        isTrue,
      );
    }
    expect(
      () => engine.requestHint(game.id, round.number, Category.city),
      throwsA(isA<OfflineError>()),
    );
  });

  testWidgets('without a server, solo games run offline', (tester) async {
    final unreachable = ApiClient(
      client: MockClient(
        (_) async => throw const SocketException('no network'),
      ),
      baseUrl: 'http://test',
    );
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(
        feedback: testFeedback(),
        home: SoloSetupScreen(apiClient: unreachable),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PLAY'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No connection: playing solo offline'), findsOneWidget);
    expect(find.byType(SoloGameScreen), findsOneWidget);
  });
}
