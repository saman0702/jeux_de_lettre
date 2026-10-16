/// Portage de la normalisation des réponses du serveur
/// (backend/app/services/normalization.py).
///
/// « Éléphant », « elephant  » et « ELEPHANT » deviennent tous « elephant ». La
/// suppression des accents utilise la table exportée depuis le serveur : les
/// deux côtés produisent les mêmes clés ; test/offline_test.dart le vérifie sur
/// des résultats du serveur.
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

  /// Caractère non ASCII -> texte simplifié (é -> e, œ -> oe, ß -> ss).
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

  /// Vrai si la réponse commence par la lettre, avec ou sans son article.
  static bool startsWithLetter(String normalized, String letter) {
    final upper = letter.toUpperCase();
    return firstLetter(normalized) == upper ||
        firstLetter(stripArticle(normalized)) == upper;
  }

  /// Formes normalisées à chercher, de la plus précise à la plus large
  /// (articles, pluriels).
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
