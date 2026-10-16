import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../data/models.dart';
import 'normalization.dart';

/// Une réponse connue : sa clé de recherche et son affichage.
typedef Entry = ({String key, String value});

/// La base de réponses embarquée dans l'appli pour les parties solo hors ligne
/// (exportée depuis le serveur par backend/app/data/export_offline.py).
class OfflineDictionary {
  OfflineDictionary._(this.normalizer, this._byKey, this._byLetter);

  static const _anyLanguage = '*';
  static Future<OfflineDictionary>? _loading;

  final Normalizer normalizer;

  /// "catégorie|langue" -> forme normalisée -> valeur affichée.
  final Map<String, Map<String, String>> _byKey;

  /// "catégorie|langue|lettre" -> entrées, les plus connues d'abord.
  final Map<String, List<Entry>> _byLetter;

  /// Se charge une seule fois en arrière-plan ; les appels suivants partagent
  /// le même future.
  static Future<OfflineDictionary> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle);

  static Future<OfflineDictionary> _load(AssetBundle bundle) async {
    final compressed = await bundle.load('assets/data/answers.tsv.gz');
    final charMap = await bundle.loadString('assets/data/normalize_map.json');
    final parsed = await compute(_parse, compressed.buffer.asUint8List());
    final map = (jsonDecode(charMap) as Map<String, dynamic>)
        .cast<String, String>();
    return OfflineDictionary._(Normalizer(map), parsed.$1, parsed.$2);
  }

  static (Map<String, Map<String, String>>, Map<String, List<Entry>>) _parse(
    Uint8List bytes,
  ) {
    final byKey = <String, Map<String, String>>{};
    final byLetter = <String, List<Entry>>{};
    final text = utf8.decode(GZipCodec().decode(bytes));
    for (final line in const LineSplitter().convert(text)) {
      final f = line.split('\t');
      if (f.length < 5) continue;
      final (category, language, letter, key, value) = (
        f[0],
        f[1],
        f[2],
        f[3],
        f[4],
      );
      byKey.putIfAbsent('$category|$language', () => {})[key] = value;
      byLetter.putIfAbsent('$category|$language|$letter', () => []).add((
        key: key,
        value: value,
      ));
    }
    return (byKey, byLetter);
  }

  /// Valeur affichée d'une réponse connue, ou null.
  String? find(Category category, String language, String key) =>
      _byKey['${category.name}|$language']?[key] ??
      _byKey['${category.name}|$_anyLanguage']?[key];

  /// Réponses connues pour une lettre, les plus connues d'abord.
  List<Entry> answers(
    Category category,
    String language,
    String letter, {
    int? limit,
  }) {
    final own =
        _byLetter['${category.name}|$language|$letter'] ?? const <Entry>[];
    final any =
        _byLetter['${category.name}|$_anyLanguage|$letter'] ?? const <Entry>[];
    final all = own.isEmpty ? any : (any.isEmpty ? own : [...own, ...any]);
    return limit == null || all.length <= limit ? all : all.sublist(0, limit);
  }

  int count(Category category, String language, String letter) =>
      (_byLetter['${category.name}|$language|$letter']?.length ?? 0) +
      (_byLetter['${category.name}|$_anyLanguage|$letter']?.length ?? 0);
}
