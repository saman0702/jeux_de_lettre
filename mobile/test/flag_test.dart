import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:letter_battle/features/game/widgets/country_flag.dart';

void main() {
  test('a known country has a free flag, in French or English', () {
    expect(flagSpecFor('France'), 'v:blue,white,red');
    expect(flagSpecFor("Côte d'Ivoire"), 'v:orange,white,green');
    expect(flagSpecFor('Maroc'), isNotNull);
    expect(flagSpecFor('Morocco'), flagSpecFor('Maroc'));
    expect(flagSpecFor('RDC'), isNotNull);
    expect(flagSpecFor('chat'), isNull);
    expect(flagSpecFor(''), isNull);
  });

  testWidgets('every flag pattern paints', (tester) async {
    final specs = {
      flagSpecFor('France'),
      flagSpecFor('Japon'),
      flagSpecFor('Suède'),
      flagSpecFor('Suisse'),
      flagSpecFor('Palestine'),
      flagSpecFor('États-Unis'),
      flagSpecFor('Royaume-Uni'),
      flagSpecFor('Brésil'),
      flagSpecFor('Afrique du Sud'),
      flagSpecFor('Grèce'),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [for (final spec in specs) CountryFlag(spec: spec!)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
