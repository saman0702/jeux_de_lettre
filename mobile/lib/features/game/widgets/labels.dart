import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';

extension CategoryLabel on Category {
  String get emoji => switch (this) {
    Category.city => '🏙️',
    Category.country => '🌍',
    Category.animal => '🐘',
    Category.fruit => '🍎',
  };

  /// Each category has its own colour in the game.
  Color get color => switch (this) {
    Category.city => AppColors.cyan,
    Category.country => AppColors.green,
    Category.animal => AppColors.orange,
    Category.fruit => AppColors.pink,
  };

  String label(AppLocalizations l10n) => switch (this) {
    Category.city => l10n.categoryCity,
    Category.country => l10n.categoryCountry,
    Category.animal => l10n.categoryAnimal,
    Category.fruit => l10n.categoryFruit,
  };
}

extension DifficultyLabel on Difficulty {
  String label(AppLocalizations l10n) => switch (this) {
    Difficulty.easy => l10n.difficultyEasy,
    Difficulty.normal => l10n.difficultyNormal,
    Difficulty.hard => l10n.difficultyHard,
  };
}

extension AnswerStatusLabel on AnswerStatus {
  String label(AppLocalizations l10n) => switch (this) {
    AnswerStatus.valid => l10n.statusValid,
    AnswerStatus.empty => l10n.statusEmpty,
    AnswerStatus.wrongLetter => l10n.statusWrongLetter,
    AnswerStatus.notFound => l10n.statusNotFound,
    AnswerStatus.late => l10n.statusLate,
    AnswerStatus.hintWrong => l10n.statusHintWrong,
  };

  Color get color =>
      this == AnswerStatus.valid ? AppColors.green : AppColors.red;

  IconData get icon =>
      this == AnswerStatus.valid ? Icons.check_circle : Icons.cancel;
}

String hintErrorMessage(AppLocalizations l10n, String code) => switch (code) {
  'no_hints_left' => l10n.hintNoneLeft,
  'no_hint_available' => l10n.hintUnavailable,
  _ => errorMessage(l10n, code),
};

String errorMessage(AppLocalizations l10n, String? code) => switch (code) {
  'network_error' => l10n.errorNetwork,
  'room_not_found' => l10n.errorRoomNotFound,
  'room_full' => l10n.errorRoomFull,
  'game_in_progress' => l10n.errorGameInProgress,
  'not_host' => l10n.errorNotHost,
  _ => l10n.errorGeneric,
};

const _accents = 'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖòóôõöÙÚÛÜùúûüÝýÿ';
const _plain = 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOoooooUUUUuuuuYyy';

/// First letter of an answer without its accent, e.g. "Éléphant" -> "E".
/// Only a visual hint: the server does the real validation.
String firstLetterOf(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) return '';
  final char = trimmed[0];
  final index = _accents.indexOf(char);
  return (index >= 0 ? _plain[index] : char).toUpperCase();
}
