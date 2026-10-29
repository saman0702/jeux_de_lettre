import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../game/widgets/country_flag.dart';
import 'origin_countries.dart';

/// Nom du pays [id] dans la langue de l'appli (l'identifiant est le nom
/// anglais).
String countryName(String id, String languageCode) {
  for (final c in originCountries) {
    if (c.id == id) return languageCode == 'fr' ? c.fr : c.en;
  }
  return id;
}

/// Petit drapeau du pays d'origine, rien si le pays est inconnu.
class CountryBadge extends StatelessWidget {
  const CountryBadge({super.key, required this.country, this.width = 20});

  final String? country;
  final double width;

  @override
  Widget build(BuildContext context) {
    final id = country;
    final spec = id == null ? null : flagSpecFor(id);
    if (spec == null) return const SizedBox.shrink();
    return Semantics(
      label: countryName(id!, Localizations.localeOf(context).languageCode),
      child: CountryFlag(
        key: const Key('country_badge'),
        spec: spec,
        width: width,
      ),
    );
  }
}

/// Liste des pays avec recherche ; renvoie l'identifiant choisi.
Future<String?> pickCountry(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CountrySheet(current: current),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.current});

  final String? current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final query = foldCountryName(_query);
    final countries =
        [
          for (final c in originCountries)
            if (query.isEmpty ||
                foldCountryName(c.fr).contains(query) ||
                foldCountryName(c.en).contains(query))
              c,
        ]..sort(
          (a, b) =>
              foldCountryName(language == 'fr' ? a.fr : a.en)
                  .compareTo(foldCountryName(language == 'fr' ? b.fr : b.en)),
        );
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                l10n.countryPickTitle,
                style: gameFont(size: 22, color: AppColors.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('country_search'),
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                style: fredoka(size: 16, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: l10n.countrySearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.cloud,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, i) {
                  final c = countries[i];
                  final spec = flagSpecFor(c.id) ?? flagSpecFor(c.fr);
                  return ListTile(
                    key: Key('country_${c.id}'),
                    leading: SizedBox(
                      width: 32,
                      child: spec == null
                          ? const Icon(
                              Icons.flag_outlined,
                              color: AppColors.grey,
                            )
                          : CountryFlag(spec: spec, width: 32),
                    ),
                    title: Text(
                      language == 'fr' ? c.fr : c.en,
                      style: fredoka(size: 16, weight: FontWeight.w600),
                    ),
                    trailing: c.id == widget.current
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.green,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, c.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Pays » : drapeau et nom du pays choisi, ou « Choisir ».
class CountryButton extends StatelessWidget {
  const CountryButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final id = value;
    return OutlinedButton(
      key: const Key('country_button'),
      onPressed: () async {
        final picked = await pickCountry(context, current: value);
        if (picked != null) onChanged(picked);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (id != null) ...[
            CountryBadge(country: id, width: 24),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              id == null ? l10n.countryChoose : countryName(id, language),
              overflow: TextOverflow.ellipsis,
              style: fredoka(size: 15, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
