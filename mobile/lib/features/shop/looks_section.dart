import 'package:flutter/material.dart';

import '../../core/audio/game_audio.dart';
import '../../core/feedback/game_feedback.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/candy_button.dart';
import '../../core/widgets/game_card.dart';
import '../../core/widgets/game_icon.dart';
import '../../l10n/app_localizations.dart';
import '../avatar/drawn_avatar.dart';
import '../game/widgets/labels.dart';
import '../online/online_controller.dart';
import '../online/widgets/player_avatar.dart';
import '../wallet/wallet.dart';
import 'cosmetics.dart';
import 'look_styles.dart';

/// Boutique d'apparences : aperçu avatar, rayons, grille produits.
class LooksSection extends StatefulWidget {
  const LooksSection({super.key, required this.api, required this.clientId});

  final ApiClient api;
  final String clientId;

  @override
  State<LooksSection> createState() => _LooksSectionState();
}

class _LooksSectionState extends State<LooksSection> {
  PlayerLook _look = const PlayerLook();
  String _kind = cosmeticKinds.first;
  Cosmetic? _preview;
  CosmeticPack? _packPreview;
  String? _busy;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await widget.api.getJson(
        '/api/v1/profiles/${widget.clientId}',
      );
      final raw = json['look'];
      if (!mounted) return;
      setState(() {
        if (raw is Map<String, dynamic>) {
          _look = PlayerLook.fromJson(raw);
        }
        _loaded = true;
      });
      if (raw is Map<String, dynamic>) _remember(_look);
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _remember(PlayerLook look) {
    OnlineScope.of(context).applyLook(look);
  }

  Future<void> _act(String path, Map<String, dynamic> body, String busy) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final feedback = GameFeedbackScope.of(context);
    setState(() => _busy = busy);
    try {
      final json = await widget.api.postJson(
        '/api/v1/profiles/${widget.clientId}/cosmetics/$path',
        body,
      );
      if (!mounted) return;
      final look = PlayerLook.fromJson(json['look'] as Map<String, dynamic>);
      OnlineScope.of(context).applyWallet(WalletSnapshot.fromJson(json));
      setState(() {
        _look = look;
        _preview = null;
        _packPreview = null;
      });
      _remember(look);
      feedback.play(Sfx.valid);
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'not_enough_coins'
                ? l10n.looksNotEnough
                : errorMessage(l10n, error.code),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  PlayerLook get _shown {
    if (_packPreview != null) return _look.withPackPreview(_packPreview!);
    return _look.withPreview(_preview);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_loaded) return const SizedBox.shrink();
    final online = OnlineScope.of(context);
    final items = cosmetics.where((item) => item.kind == _kind).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.looksTitle,
          textAlign: TextAlign.center,
          style: fredoka(
            size: 22,
            weight: FontWeight.w700,
            color: AppColors.white,
            shadows: textShadow,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.looksSubtitle,
          textAlign: TextAlign.center,
          style: fredoka(
            size: 13,
            weight: FontWeight.w500,
            color: AppColors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 12),
        _StoreHero(
          preset: online.avatarPreset,
          photoUrl: online.avatarUrl,
          look: _shown,
          nickname:
              GameFeedbackScope.of(context).settings.nickname ??
              l10n.defaultNickname,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cosmeticKinds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final kind = cosmeticKinds[i];
              final selected = kind == _kind;
              return GestureDetector(
                key: Key('shop_aisle_$kind'),
                onTap: () => setState(() {
                  _kind = kind;
                  _preview = null;
                  _packPreview = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.yellow
                        : AppColors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.white
                          : AppColors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    cosmeticKindLabel(l10n, kind),
                    style: fredoka(
                      size: 14,
                      weight: FontWeight.w700,
                      color: selected ? AppColors.ink : AppColors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cosmeticKindHint(l10n, _kind),
          textAlign: TextAlign.center,
          style: fredoka(
            size: 12,
            weight: FontWeight.w500,
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 10),
        if (_kind == 'pack')
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cosmeticPacks.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) {
              final pack = cosmeticPacks[i];
              return _PackCard(
                pack: pack,
                look: _look,
                preset: online.avatarPreset,
                selected: _packPreview?.id == pack.id,
                busy: _busy == pack.id,
                enabled: _busy == null,
                onTap: () => setState(() {
                  _packPreview = pack;
                  _preview = null;
                }),
                onBuy: () => _act('buy', {'item_id': pack.id}, pack.id),
              );
            },
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, i) {
              final item = items[i];
              return _ProductCard(
                item: item,
                look: _look,
                preset: online.avatarPreset,
                selected:
                    _preview?.id == item.id ||
                    (_preview == null &&
                        _packPreview == null &&
                        _look.equipped(item)),
                busy: _busy == item.id,
                enabled: _busy == null,
                onTap: () => setState(() {
                  _preview = item;
                  _packPreview = null;
                }),
                onBuy: () => _act('buy', {'item_id': item.id}, item.id),
                onEquip: () => _act('equip', {'item_id': item.id}, item.id),
                onUnequip: () =>
                    _act('unequip', {'kind': item.kind}, item.id),
              );
            },
          ),
      ],
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.preset,
    required this.photoUrl,
    required this.look,
    required this.nickname,
  });

  final int preset;
  final String? photoUrl;
  final PlayerLook look;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GameCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Text(
            l10n.looksPreview,
            style: fredoka(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          PlayerAvatar(
            nickname: nickname,
            seed: 'preview',
            size: 112,
            preset: preset,
            photoUrl: photoUrl,
            frame: look.frame,
            hair: look.hair,
            hat: look.hat,
          ),
          const SizedBox(height: 10),
          StyledNickname(
            nickname.isEmpty ? '…' : nickname,
            styleId: look.name,
            size: 20,
            weight: FontWeight.w800,
          ),
          if (look.tiles.isNotEmpty || look.victory.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (look.tiles.isNotEmpty)
                  TilePatternPreview(patternId: look.tiles, size: 30),
                if (look.tiles.isNotEmpty && look.victory.isNotEmpty)
                  const SizedBox(width: 10),
                if (look.victory.isNotEmpty)
                  Icon(
                    switch (victoryShapeOf(look.victory)) {
                      VictoryShape.stars => Icons.star_rounded,
                      VictoryShape.bubbles => Icons.bubble_chart_rounded,
                      VictoryShape.letters => Icons.font_download_rounded,
                      VictoryShape.confetti => Icons.celebration,
                    },
                    color: cosmeticOf(look.victory)?.color ?? AppColors.yellow,
                    size: 28,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.look,
    required this.preset,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onBuy,
  });

  final CosmeticPack pack;
  final PlayerLook look;
  final int preset;
  final bool selected;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owned = look.owns(pack.id);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? pack.color : AppColors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(selected ? pack.color : AppColors.white),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: PlayerAvatar(
                  nickname: 'P',
                  seed: pack.id,
                  size: 64,
                  preset: preset,
                  frame: pack.items.firstWhere(
                    (id) => id.startsWith('frame_'),
                    orElse: () => '',
                  ),
                ),
              ),
            ),
            Text(
              cosmeticPackLabel(l10n, pack),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fredoka(size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.looksPackContents(pack.items.length),
              style: fredoka(size: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 6),
            CandyButton(
              key: Key('cosmetic_${pack.id}'),
              label: owned ? l10n.looksOwned : l10n.looksPrice(pack.price),
              gameIcon: owned ? GameIconKind.check : GameIconKind.coin,
              color: owned ? AppColors.green : AppColors.yellow,
              textColor: owned ? AppColors.white : AppColors.ink,
              height: 38,
              fontSize: 12,
              loading: busy,
              onPressed: !enabled || owned ? null : onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    required this.look,
    required this.preset,
    required this.selected,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  final Cosmetic item;
  final PlayerLook look;
  final int preset;
  final bool selected;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owned = look.owns(item.id);
    final equipped = look.equipped(item);
    final label = equipped
        ? l10n.looksEquipped
        : owned
        ? l10n.looksEquip
        : l10n.looksPrice(item.price);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? item.color : AppColors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.depthOf(selected ? item.color : AppColors.white),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _ProductArt(item: item, preset: preset),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cosmeticLabel(l10n, item),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fredoka(size: 14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            CandyButton(
              key: Key('cosmetic_${item.id}'),
              label: label,
              gameIcon: equipped ? GameIconKind.check : GameIconKind.coin,
              color: equipped ? AppColors.green : AppColors.yellow,
              textColor: equipped ? AppColors.white : AppColors.ink,
              height: 38,
              fontSize: 12,
              loading: busy,
              onPressed: !enabled
                  ? null
                  : equipped
                  ? onUnequip
                  : owned
                  ? onEquip
                  : onBuy,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductArt extends StatelessWidget {
  const _ProductArt({required this.item, required this.preset});

  final Cosmetic item;
  final int preset;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case 'hair':
        return DrawnAvatar(preset: preset, size: 72, hairId: item.id);
      case 'hat':
        return DrawnAvatar(preset: preset, size: 72, hatId: item.id);
      case 'frame':
        return PlayerAvatar(
          nickname: 'A',
          seed: item.id,
          size: 64,
          preset: preset,
          frame: item.id,
        );
      case 'name':
        return StyledNickname(
          'Aa',
          styleId: item.id,
          size: 28,
          weight: FontWeight.w800,
        );
      case 'tiles':
        return TilePatternPreview(patternId: item.id, size: 40);
      default:
        return Icon(
          switch (victoryShapeOf(item.id)) {
            VictoryShape.stars => Icons.star_rounded,
            VictoryShape.bubbles => Icons.bubble_chart_rounded,
            VictoryShape.letters => Icons.font_download_rounded,
            VictoryShape.confetti => Icons.celebration,
          },
          size: 40,
          color: item.color,
        );
    }
  }
}
