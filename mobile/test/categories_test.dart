import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/features/game/data/models.dart';
import 'package:letter_battle/features/game/solo_setup_screen.dart';
import 'package:letter_battle/main.dart';

import 'solo_game_test.dart' show FakeServer;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  test('first-name categories use the server ids', () {
    expect(Category.femaleName.wire, 'female_name');
    expect(Category.fromWire('male_name'), Category.maleName);
    expect(Category.classic, hasLength(4));
  });

  testWidgets('five categories or more need rounds longer than 30 s', (
    tester,
  ) async {
    final server = FakeServer();
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    await tester.pumpWidget(
      LetterBattleApp(home: SoloSetupScreen(apiClient: server.api)),
    );
    await tester.pumpAndSettle();

    // Par défaut : les 4 catégories classiques, 30 s.
    expect(find.text("Girl's name"), findsOneWidget);
    expect(find.byKey(const Key('many_categories_hint')), findsNothing);

    await tapText(tester, "Girl's name");
    expect(find.byKey(const Key('many_categories_hint')), findsOneWidget);
    expect(find.text('15 s'), findsNothing);
    expect(find.text('30 s'), findsNothing);

    await tapText(tester, "Boy's name");
    await tester.tap(find.text('PLAY'));
    await tester.pump(const Duration(seconds: 1));
    expect(server.createdWith!['round_duration'], 45);
    expect(server.createdWith!['categories'], [
      'city',
      'country',
      'animal',
      'fruit',
      'female_name',
      'male_name',
    ]);
    await tester.pump(const Duration(seconds: 1));
  });
}
