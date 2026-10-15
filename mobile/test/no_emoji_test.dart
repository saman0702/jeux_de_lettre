import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Emojis look different on every phone; the app draws its own animated
/// icons (lib/core/widgets/game_icon.dart) instead.
final _emoji = RegExp(
  '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}\u{23F1}\u{231A}\u{2328}]',
  unicode: true,
);

void main() {
  test('no emoji in the app code or texts', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') || f.path.endsWith('.arb'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (_emoji.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
