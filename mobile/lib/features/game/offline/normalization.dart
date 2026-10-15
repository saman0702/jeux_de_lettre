/// Port of the server's answer normalization (backend/app/services/normalization.py).
///
/// "Éléphant", "elephant " and "ELEPHANT" all become "elephant". Accent
/// folding uses the table exported from the server, so both sides produce
/// the same keys; test/offline_test.dart checks it against server output.
library;

import '../data/models.dart';

final _separators = RegExp(r"[\s\-‐‑–—'’`´.,/_]+");
final _nonAlnum = RegExp('[^a-z0-9 ]');
final _leadingArticle = RegExp(
  r'^(?:le|la|les|l|un|une|des|du|the|a|an) (?=.)',
);

const _commonNouns = {Category.animal, Category.fruit};
const _articleCategories = {Category.animal, Category.fruit, Category.country};

class Normalizer {
  const Normalizer(this._charMap);

  /// Non-ASCII character -> folded text (é -> e, œ -> oe, ß -> ss).
  final Map<String, String> _charMap;

  String normalize(String text) {
    final folded = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      folded.write(rune < 0x80 ? char.toLowerCase() : (_charMap[char] ?? char));
    }
    final cleaned = folded
        .toString()
        .replaceAll(_separators, ' ')
        .replaceAll(_nonAlnum, '');
    return cleaned.split(' ').where((part) => part.isNotEmpty).join(' ');
  }

  static String stripArticle(String normalized) =>
      normalized.replaceFirst(_leadingArticle, '');

  static String firstLetter(String normalized) =>
      normalized.isEmpty ? '' : normalized[0].toUpperCase();

  /// True if the answer starts with the letter, with or without its article.
  static bool startsWithLetter(String normalized, String letter) {
    final upper = letter.toUpperCase();
    return firstLetter(normalized) == upper ||
        firstLetter(stripArticle(normalized)) == upper;
  }

  /// Normalized forms to look up, most specific first (articles, plurals).
  List<String> lookupKeys(String raw, Category category) {
    final base = normalize(raw);
    if (base.isEmpty) return const [];
    final keys = [base];
    if (_articleCategories.contains(category)) keys.add(stripArticle(base));
    if (_commonNouns.contains(category)) {
      for (final key in [...keys]) {
        for (final suffix in const ['es', 's', 'x']) {
          if (key.endsWith(suffix) && key.length > suffix.length + 2) {
            keys.add(key.substring(0, key.length - suffix.length));
          }
        }
      }
    }
    return [
      ...{...keys},
    ];
  }
}
