import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/features/chrono/chrono_bank.dart';
import 'package:letter_battle/features/chrono/chrono_hub_screen.dart';
import 'package:letter_battle/features/mots/mots_bank.dart';
import 'package:letter_battle/features/quiz/quiz_solo_screen.dart';
import 'package:letter_battle/core/theme/app_colors.dart';
import 'package:letter_battle/core/widgets/game_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iq_test.dart' show tallPhone, tapKey;
import 'online_test.dart' show Harness, pumpFor;
// Mots hub smoke covered via bank + same QuizSoloScreen.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('chrono and mots banks have bilingual QCM', () {
    for (final q in [...chronoBank(), ...motsBank()]) {
      expect(q.prompt['fr'], isNotEmpty);
      expect(q.prompt['en'], isNotEmpty);
      expect(q.choices['fr'], hasLength(4));
      expect(q.choices['en'], hasLength(4));
      expect(q.isCorrect(q.answer), isTrue);
      expect(q.isCorrect((q.answer + 1) % 4), isFalse);
    }
  });

  testWidgets('chrono solo: answer then see score', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(
      tester,
      QuizSoloScreen(
        title: 'Chrono',
        theme: BackgroundTheme.letters,
        accent: AppColors.ochre,
        questions: chronoBank().take(2).toList(),
        game: 'chrono',
        rounds: 2,
        secondsPerQuestion: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('quiz_prompt')), findsOneWidget);
    await tapKey(tester, 'quiz_choice_0');
    expect(find.byKey(const Key('quiz_answer')), findsOneWidget);
    await tapKey(tester, 'quiz_next');
    await tester.pump();
    await tapKey(tester, 'quiz_choice_0');
    await tapKey(tester, 'quiz_next');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('quiz_score')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chrono hub opens solo', (tester) async {
    tallPhone(tester);
    final h = Harness();
    await h.start(tester, const ChronoHubScreen());
    expect(find.byKey(const Key('chrono_solo')), findsOneWidget);
    await tapKey(tester, 'chrono_solo');
    await pumpFor(tester, const Duration(milliseconds: 400));
    expect(find.byKey(const Key('quiz_prompt')), findsOneWidget);
    expect(find.byKey(const Key('quiz_choice_0')), findsOneWidget);
    expect(find.byKey(const Key('quiz_choice_3')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
