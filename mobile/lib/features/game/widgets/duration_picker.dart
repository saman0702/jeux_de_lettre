import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import 'labels.dart';
import 'pill_selector.dart';

/// Sélecteur de durée : illimité (0) + presets + saisie manuelle en secondes.
class DurationPicker extends StatelessWidget {
  const DurationPicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  /// 0 = illimité.
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pills = [
      SoloGameSettings.unlimitedDuration,
      ...options.where((d) => d > 0),
    ];
    return Column(
      children: [
        PillSelector<int>(
          options: pills,
          isSelected: (d) => d == value,
          label: (d) => durationLabel(l10n, d),
          onTap: onChanged,
        ),
        const SizedBox(height: 10),
        _CustomSecondsField(value: value, onChanged: onChanged),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            key: const Key('many_categories_hint'),
            textAlign: TextAlign.center,
            style: fredoka(size: 13, color: AppColors.inkSoft),
          ),
        ],
      ],
    );
  }
}

class _CustomSecondsField extends StatefulWidget {
  const _CustomSecondsField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_CustomSecondsField> createState() => _CustomSecondsFieldState();
}

class _CustomSecondsFieldState extends State<_CustomSecondsField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value > 0 ? '${widget.value}' : '',
    );
  }

  @override
  void didUpdateWidget(_CustomSecondsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focus.hasFocus) return;
    final next = widget.value > 0 ? '${widget.value}' : '';
    if (_controller.text != next) _controller.text = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    final clamped = parsed.clamp(
      SoloGameSettings.minCustomDuration,
      SoloGameSettings.maxCustomDuration,
    );
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const Key('custom_duration'),
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: fredoka(size: 16, weight: FontWeight.w600, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: l10n.customDurationHint,
        hintStyle: fredoka(size: 14, color: AppColors.inkSoft),
        filled: true,
        fillColor: AppColors.cloud,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: _apply,
      onSubmitted: _apply,
    );
  }
}
