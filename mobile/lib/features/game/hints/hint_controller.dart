import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../widgets/labels.dart';
import 'hint_picker.dart';

/// Where hints come from: the solo REST API or the room WebSocket.
abstract class HintSource {
  Future<HintOptions> request(Category category);
  Future<HintPick> pick(Category category, String choice);
}

class HintFieldState {
  const HintFieldState({required this.options, this.picked, this.correct});

  final List<String> options;
  final String? picked;
  final bool? correct;

  /// Once an option is picked the field is locked for the round.
  bool get locked => picked != null;
}

/// Hint state of one round: which fields used a hint and how many are left.
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

  /// A hint button is shown if one is left, or to reopen unpicked options.
  bool canHint(Category category) {
    final state = _fields[category];
    if (state != null) return !state.locked;
    return _hintsLeft > 0;
  }

  /// Requests the options, lets the player choose, and fills [controller].
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
    } finally {
      _busy = false;
    }
  }
}
