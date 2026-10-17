import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../animations/bounce_in.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/game_icon.dart';
import '../../../core/widgets/letter_tile.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import '../hints/hint_controller.dart';
import '../../shop/cosmetics.dart';
import '../../shop/look_styles.dart';
import 'country_flag.dart';
import 'labels.dart';

/// Réponse la plus longue acceptée, utilisée aussi par le clavier de jeu.
const answerMaxLength = 24;

/// Saisie des réponses façon jeu : les lettres tapées deviennent des tuiles qui
/// apparaissent avec un « toc », la catégorie s'affiche en badge coloré et le
/// champ actif brille.
///
/// Un vrai TextField (invisible) gère toujours le clavier, la saisie et
/// l'accessibilité ; seul son affichage est remplacé.
class AnswerSlot extends StatefulWidget {
  const AnswerSlot({
    super.key,
    required this.category,
    required this.controller,
    required this.letter,
    required this.enabled,
    required this.autofocus,
    required this.isLast,
    required this.onDone,
    this.hints,
    this.focusNode,
    this.systemKeyboard = true,
  });

  final Category category;
  final TextEditingController controller;
  final String letter;
  final bool enabled;
  final bool autofocus;
  final bool isLast;
  final VoidCallback onDone;
  final HintController? hints;

  /// Fourni quand l'écran de manche pilote le focus (clavier de jeu).
  final FocusNode? focusNode;

  /// Faux avec le clavier de jeu : le champ garde le focus mais le clavier du
  /// téléphone reste caché.
  final bool systemKeyboard;

  @override
  State<AnswerSlot> createState() => _AnswerSlotState();
}

class _AnswerSlotState extends State<AnswerSlot>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  final _scroll = ScrollController();
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  String _previous = '';
  bool _matched = false;

  @override
  void initState() {
    super.initState();
    _previous = widget.controller.text;
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
    _matched = _matches;
  }

  @override
  void didUpdateWidget(AnswerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _previous = widget.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    _scroll.dispose();
    _glow.dispose();
    super.dispose();
  }

  bool get _locked => widget.hints?.field(widget.category)?.locked ?? false;
  bool get _matches =>
      !_locked && firstLetterOf(widget.controller.text) == widget.letter;

  void _onFocus() {
    if (_focus.hasFocus) {
      // Pulsation même sans motion ambiant : on doit voir clairement le
      // champ actif.
      _glow.repeat(reverse: true);
    } else {
      _glow
        ..stop()
        ..value = 0;
    }
    setState(() {});
  }

  void _onText() {
    final text = widget.controller.text;
    if (_focus.hasFocus && text != _previous) {
      final feedback = GameFeedbackScope.of(context);
      if (text.length > _previous.length) {
        feedback.play(Sfx.key);
        feedback.haptic(Haptic.light);
      } else if (text.length < _previous.length) {
        feedback.play(Sfx.erase);
      }
      if (_matches && !_matched) feedback.play(Sfx.match);
    }
    _matched = _matches;
    _previous = text;
    // Garde la dernière tuile visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = widget.category;
    final hints = widget.hints;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, ?hints, _glow]),
      builder: (context, _) {
        final hint = hints?.field(category);
        final locked = _locked;
        final matches = _matches;
        final focused = _focus.hasFocus;
        final accent = locked
            ? (hint!.correct! ? AppColors.green : AppColors.red)
            : matches
            ? AppColors.green
            : category.color;
        final glow = focused ? 0.4 + 0.35 * _glow.value : 0.0;

        return GestureDetector(
          onTap: widget.enabled && !locked ? _focus.requestFocus : null,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: focused || locked || !widget.enabled ? 1 : 0.72,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: focused ? 1.04 : 1,
                alignment: Alignment.center,
                child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: focused ? 68 : 64,
                  decoration: BoxDecoration(
                    color: focused
                        ? Color.lerp(AppColors.white, accent, 0.14)!
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: focused
                          ? accent
                          : accent.withValues(alpha: 0.55),
                      width: focused ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(accent),
                        offset: Offset(0, focused ? 6 : 4),
                      ),
                      if (focused) ...[
                        BoxShadow(
                          color: accent.withValues(alpha: glow),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: AppColors.white.withValues(alpha: 0.85),
                          blurRadius: 0,
                          spreadRadius: -1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      _CountryOrBadge(
                        category: category,
                        text: widget.controller.text,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // La vraie saisie, invisible : les tuiles en
                            // dessous affichent son texte.
                            Opacity(
                              opacity: 0,
                              child: TextField(
                                key: Key('field_${category.name}'),
                                controller: widget.controller,
                                focusNode: _focus,
                                enabled: widget.enabled && !locked,
                                autofocus: widget.autofocus,
                                autocorrect: false,
                                enableSuggestions: false,
                                enableInteractiveSelection: false,
                                showCursor: false,
                                keyboardType: widget.systemKeyboard
                                    ? TextInputType.text
                                    : TextInputType.none,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(
                                    answerMaxLength,
                                  ),
                                ],
                                textInputAction: widget.isLast
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                onSubmitted: widget.isLast
                                    ? (_) => widget.onDone()
                                    : null,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: _Tiles(
                                text: widget.controller.text,
                                letter: widget.letter,
                                color: category.color,
                                focused: focused,
                                blink: _glow.value,
                                scroll: _scroll,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Trailing(
                        locked: locked,
                        correct: hint?.correct,
                        matches: matches,
                        canHint:
                            hints != null &&
                            widget.enabled &&
                            hints.canHint(category),
                        canBuyHint:
                            hints != null &&
                            widget.enabled &&
                            hints.canBuyHint(category),
                        hintsLeft: hints?.hintsLeft ?? 0,
                        hintKey: Key('hint_${category.name}'),
                        onHint: () =>
                            hints!.use(context, category, widget.controller),
                        onBuyHint: () => hints!.buyAndUse(
                          context,
                          category,
                          widget.controller,
                        ),
                      ),
                    ],
                  ),
                ),
                // Étiquette façon affichage de jeu, posée sur le bord.
                Positioned(
                  top: focused ? -12 : -10,
                  left: 18,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: focused ? 1.08 : 1,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: focused ? 10 : 8,
                        vertical: focused ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.white,
                          width: focused ? 2.5 : 2,
                        ),
                        boxShadow: focused
                            ? [
                                BoxShadow(
                                  color: AppColors.depthOf(accent),
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        category.label(l10n).toUpperCase(),
                        style: fredoka(
                          size: focused ? 12 : 11,
                          weight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountryOrBadge extends StatelessWidget {
  const _CountryOrBadge({required this.category, required this.text});

  final Category category;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spec = category == Category.country ? flagSpecFor(text) : null;
    if (spec == null) return _CategoryBadge(category: category);
    return CountryFlag(spec: spec, width: 42);
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return GameIconBadge(category.icon, color: category.color, size: 40);
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.text,
    required this.letter,
    required this.color,
    required this.focused,
    required this.blink,
    required this.scroll,
  });

  final String text;
  final String letter;
  final Color color;
  final bool focused;
  final double blink;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final tileStyle = GameFeedbackScope.of(context).settings.tileStyle;
    final bought = cosmeticOf(tileStyle)?.color;
    final tileColor = bought ?? Color.lerp(color, Colors.white, 0.6)!;
    final pattern = tilePatternOf(tileStyle);
    final chars = text.characters.toList();

    if (chars.isEmpty && !focused) {
      // Indice fantôme : la lettre par laquelle commencer.
      return Opacity(
        opacity: 0.35,
        child: Row(
          children: [
            LetterTile(
              letter: letter,
              size: 32,
              color: tileColor,
              pattern: pattern,
            ),
            const SizedBox(width: 6),
            Text(
              '…',
              style: fredoka(
                size: 24,
                weight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ),
      );
    }

    // Les tuiles rétrécissent pour que le mot entier reste visible, jusqu'à une
    // taille encore lisible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = chars.length + (focused ? 1 : 0);
        final fit = slots == 0 ? 30.0 : constraints.maxWidth / slots - 3;
        final size = fit.clamp(18.0, 30.0);
        return SizedBox(
          height: 40,
          child: ListView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, char) in chars.indexed)
                if (char.trim().isEmpty)
                  SizedBox(width: size / 3)
                else
                  Padding(
                    padding: EdgeInsets.only(
                      right: 3,
                      top: (30 - size) / 2 + 2,
                    ),
                    child: BounceIn(
                      key: ValueKey('$i$char'),
                      from: 0.2,
                      duration: const Duration(milliseconds: 260),
                      child: Transform.rotate(
                        angle: (i.isEven ? 1 : -1) * 0.03,
                        child: LetterTile(
                          letter: char.toUpperCase(),
                          size: size,
                          color: tileColor,
                          pattern: pattern,
                        ),
                      ),
                    ),
                  ),
              if (focused && chars.length < answerMaxLength)
                Padding(
                  padding: EdgeInsets.only(top: (30 - size) / 2 + 4),
                  child: Opacity(
                    opacity: 0.55 + 0.45 * (1 - (2 * blink - 1).abs()),
                    child: Container(
                      width: size - 2,
                      height: size,
                      decoration: BoxDecoration(
                        color: Color.lerp(tileColor, color, 0.25),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: color, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.locked,
    required this.correct,
    required this.matches,
    required this.canHint,
    required this.canBuyHint,
    required this.hintsLeft,
    required this.hintKey,
    required this.onHint,
    required this.onBuyHint,
  });

  final bool locked;
  final bool? correct;
  final bool matches;
  final bool canHint;
  final bool canBuyHint;
  final int hintsLeft;
  final Key hintKey;
  final VoidCallback onHint;
  final VoidCallback onBuyHint;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            const GameIcon(
              GameIconKind.hint,
              size: 22,
              color: AppColors.yellow,
            ),
            Icon(
              correct! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct! ? AppColors.green : AppColors.red,
              size: 28,
            ),
          ],
        ),
      );
    }
    if (matches) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (context, t, child) => Transform.rotate(
            angle: (1 - t) * pi / 2,
            child: Transform.scale(scale: t, child: child),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 30,
          ),
        ),
      );
    }
    if (canBuyHint) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          key: Key('${hintKey}_buy'),
          onTap: onBuyHint,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.depthOf(AppColors.orange),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const GameIcon(GameIconKind.hint, size: 22),
              ),
              Positioned(
                top: -6,
                right: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.depthOf(AppColors.yellow),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const GameIcon(GameIconKind.coin, size: 11),
                      const SizedBox(width: 2),
                      Text(
                        '$extraHintPrice',
                        style: fredoka(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!canHint) return const SizedBox(width: 12);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        key: hintKey,
        onTap: onHint,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.depthOf(AppColors.yellow),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const GameIcon(GameIconKind.hint, size: 24),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: CircleAvatar(
                radius: 9,
                backgroundColor: AppColors.purple,
                child: Text(
                  '$hintsLeft',
                  style: fredoka(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
