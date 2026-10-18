import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_dialog.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../offline/offline_engine.dart';
import '../widgets/labels.dart';
import 'hint_picker.dart';

/// D'où viennent les jokers : l'API REST du solo ou la WebSocket du salon.
abstract class HintSource {
  Future<HintOptions> request(Category category, {bool reveal = false});
  Future<HintPick> pick(Category category, String choice);

  /// Faux hors ligne : pas d'achat de joker.
  bool get canBuyExtra;
  Future<BuyHintResult> buyExtra();
}

class HintFieldState {
  const HintFieldState({required this.options, this.picked, this.correct});

  final List<String> options;
  final String? picked;
  final bool? correct;

  /// Dès qu'une proposition est choisie, le champ est verrouillé pour la
  /// manche.
  bool get locked => picked != null;
}

/// État des jokers d'une manche : quels champs en ont utilisé un et combien il
/// en reste.
class HintController extends ChangeNotifier {
  HintController({
    required this.source,
    required this._hintsLeft,
    required this.letter,
  });

  final HintSource source;
  final String letter;
  final Map<Category, HintFieldState> _fields = {};
  int _hintsLeft;
  bool _busy = false;

  int get hintsLeft => _hintsLeft;
  HintFieldState? field(Category category) => _fields[category];

  /// Le bouton joker s'affiche s'il en reste un, ou pour rouvrir des
  /// propositions non choisies.
  bool canHint(Category category) {
    final state = _fields[category];
    if (state != null) return !state.locked;
    return _hintsLeft > 0;
  }

  /// Achat d'un joker quand le quota gratuit est épuisé.
  bool canBuyHint(Category category) {
    if (_fields[category] != null) return false;
    return _hintsLeft <= 0 && source.canBuyExtra;
  }

  /// Achète un joker puis ouvre le sélecteur pour [category].
  Future<void> buyAndUse(
    BuildContext context,
    Category category,
    TextEditingController controller,
  ) async {
    if (_busy || !canBuyHint(category)) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showGameConfirm(
      context,
      icon: GameIconKind.hint,
      title: l10n.buyHintTitle,
      message: l10n.buyHintMessage(extraHintPrice),
      confirmLabel: l10n.buyHintConfirm(extraHintPrice),
      cancelLabel: l10n.cancel,
      accent: AppColors.yellow,
    );
    if (!ok || !context.mounted) return;
    _busy = true;
    final messenger = ScaffoldMessenger.of(context);
    final feedback = GameFeedbackScope.of(context);
    try {
      final result = await source.buyExtra();
      _hintsLeft = result.hintsLeft;
      notifyListeners();
      // Joker payant : révèle le mot exact, sans QCM.
      final revealed = await source.request(category, reveal: true);
      _hintsLeft = revealed.hintsLeft;
      final word = revealed.answer ?? revealed.options.first;
      _fields[category] = HintFieldState(
        options: [word],
        picked: word,
        correct: true,
      );
      controller.text = word;
      feedback.play(Sfx.valid);
      feedback.haptic(Haptic.medium);
      notifyListeners();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(hintErrorMessage(l10n, e.code))),
      );
    } on OfflineError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(hintErrorMessage(l10n, e.code))),
      );
    } finally {
      _busy = false;
    }
  }

  /// Demande les propositions, laisse le joueur choisir et remplit
  /// [controller].
  Future<void> use(
    BuildContext context,
    Category category,
    TextEditingController controller,
  ) async {
    if (_busy || !canHint(category)) return;
    _busy = true;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final feedback = GameFeedbackScope.of(context);
    try {
      var state = _fields[category];
      if (state == null) {
        final options = await source.request(category);
        _hintsLeft = options.hintsLeft;
        state = HintFieldState(options: options.options);
        _fields[category] = state;
        notifyListeners();
      }
      if (!context.mounted) return;
      feedback.play(Sfx.hintOpen);
      final choice = await showHintPicker(
        context,
        category: category,
        letter: letter,
        options: state.options,
      );
      if (choice == null) return;

      final result = await source.pick(category, choice);
      _fields[category] = HintFieldState(
        options: state.options,
        picked: choice,
        correct: result.correct,
      );
      controller.text = choice;
      feedback.play(result.correct ? Sfx.valid : Sfx.invalid);
      feedback.haptic(result.correct ? Haptic.medium : Haptic.heavy);
      notifyListeners();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(hintErrorMessage(l10n, e.code))),
      );
    } on OfflineError catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(hintErrorMessage(l10n, e.code))),
      );
    } finally {
      _busy = false;
    }
  }
}
