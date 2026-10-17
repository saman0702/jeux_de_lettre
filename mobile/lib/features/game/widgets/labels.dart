import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';

extension CategoryLabel on Category {
  GameIconKind get icon => switch (this) {
    Category.city => GameIconKind.city,
    Category.country => GameIconKind.country,
    Category.animal => GameIconKind.animal,
    Category.fruit => GameIconKind.fruit,
    Category.femaleName => GameIconKind.female,
    Category.maleName => GameIconKind.male,
  };

  /// Chaque catégorie a sa propre couleur dans le jeu.
  Color get color => switch (this) {
    Category.city => AppColors.cyan,
    Category.country => AppColors.green,
    Category.animal => AppColors.orange,
    Category.fruit => AppColors.pink,
    Category.femaleName => const Color(0xFFD94FD6),
    Category.maleName => AppColors.purple,
  };

  String label(AppLocalizations l10n) => switch (this) {
    Category.city => l10n.categoryCity,
    Category.country => l10n.categoryCountry,
    Category.animal => l10n.categoryAnimal,
    Category.fruit => l10n.categoryFruit,
    Category.femaleName => l10n.categoryFemaleName,
    Category.maleName => l10n.categoryMaleName,
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
    AnswerStatus.alreadyUsed => l10n.statusAlreadyUsed,
  };

  Color get color =>
      this == AnswerStatus.valid ? AppColors.green : AppColors.red;

  IconData get icon =>
      this == AnswerStatus.valid ? Icons.check_circle : Icons.cancel;
}

String hintErrorMessage(AppLocalizations l10n, String code) => switch (code) {
  'no_hints_left' => l10n.hintNoneLeft,
  'no_hint_available' => l10n.hintUnavailable,
  'not_online' => l10n.notOnlineForPurchase,
  'not_enough_coins' => l10n.looksNotEnough,
  'no_info_available' => l10n.hintUnavailable,
  _ => errorMessage(l10n, code),
};

String errorMessage(AppLocalizations l10n, String? code) => switch (code) {
  'network_error' => l10n.errorNetwork,
  'room_not_found' => l10n.errorRoomNotFound,
  'room_full' => l10n.errorRoomFull,
  'game_in_progress' => l10n.errorGameInProgress,
  'not_host' => l10n.errorNotHost,
  'not_enough_coins' => l10n.errorNotEnoughCoins,
  'bots_not_allowed' => l10n.errorBotsNotAllowed,
  _ => l10n.errorGeneric,
};

const _accents = 'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖòóôõöÙÚÛÜùúûüÝýÿ';
const _plain = 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOoooooUUUUuuuuYyy';

/// Première lettre d'une réponse sans son accent, ex. « Éléphant » -> « E ».
/// Simple indication visuelle : la vraie validation est faite par le serveur.
String firstLetterOf(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) return '';
  final char = trimmed[0];
  final index = _accents.indexOf(char);
  return (index >= 0 ? _plain[index] : char).toUpperCase();
}
