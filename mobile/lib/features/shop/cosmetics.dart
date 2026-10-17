import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'look_styles.dart';

/// Une apparence achetée avec des pièces. Les prix sont les mêmes que
/// `COSMETICS` côté serveur.
class Cosmetic {
  const Cosmetic({
    required this.id,
    required this.kind,
    required this.price,
    required this.color,
  });

  final String id;

  /// hair, hat, frame, name, tiles, victory ou pack.
  final String kind;
  final int price;
  final Color color;
}

/// Pack thématique : plusieurs apparences pour un prix réduit.
class CosmeticPack {
  const CosmeticPack({
    required this.id,
    required this.price,
    required this.color,
    required this.items,
  });

  final String id;
  final int price;
  final Color color;
  final List<String> items;
}

const cosmetics = <Cosmetic>[
  Cosmetic(id: 'hair_spiky', kind: 'hair', price: 25, color: AppColors.ink),
  Cosmetic(id: 'hair_bob', kind: 'hair', price: 25, color: AppColors.pink),
  Cosmetic(id: 'hair_curly', kind: 'hair', price: 25, color: AppColors.cyan),
  Cosmetic(id: 'hair_bun', kind: 'hair', price: 25, color: AppColors.yellow),
  Cosmetic(id: 'hat_crown', kind: 'hat', price: 40, color: AppColors.yellow),
  Cosmetic(id: 'hat_cap', kind: 'hat', price: 30, color: AppColors.red),
  Cosmetic(id: 'hat_wizard', kind: 'hat', price: 35, color: AppColors.purple),
  Cosmetic(id: 'hat_party', kind: 'hat', price: 30, color: AppColors.pink),
  Cosmetic(id: 'frame_gold', kind: 'frame', price: 15, color: AppColors.yellow),
  Cosmetic(id: 'frame_pink', kind: 'frame', price: 15, color: AppColors.pink),
  Cosmetic(id: 'frame_cyan', kind: 'frame', price: 15, color: AppColors.cyan),
  Cosmetic(
    id: 'frame_ornament',
    kind: 'frame',
    price: 25,
    color: AppColors.yellow,
  ),
  Cosmetic(
    id: 'frame_flames',
    kind: 'frame',
    price: 25,
    color: AppColors.orange,
  ),
  Cosmetic(
    id: 'frame_stars',
    kind: 'frame',
    price: 25,
    color: AppColors.purple,
  ),
  Cosmetic(id: 'name_rose', kind: 'name', price: 10, color: AppColors.pink),
  Cosmetic(
    id: 'name_violet',
    kind: 'name',
    price: 10,
    color: AppColors.purple,
  ),
  Cosmetic(
    id: 'name_orange',
    kind: 'name',
    price: 10,
    color: AppColors.orange,
  ),
  Cosmetic(
    id: 'name_gradient',
    kind: 'name',
    price: 18,
    color: AppColors.pink,
  ),
  Cosmetic(
    id: 'name_outline',
    kind: 'name',
    price: 18,
    color: AppColors.yellow,
  ),
  Cosmetic(
    id: 'name_badge',
    kind: 'name',
    price: 18,
    color: AppColors.orange,
  ),
  Cosmetic(
    id: 'tiles_sunset',
    kind: 'tiles',
    price: 20,
    color: AppColors.orange,
  ),
  Cosmetic(
    id: 'tiles_ocean',
    kind: 'tiles',
    price: 20,
    color: AppColors.cyan,
  ),
  Cosmetic(
    id: 'tiles_candy',
    kind: 'tiles',
    price: 20,
    color: AppColors.pink,
  ),
  Cosmetic(
    id: 'tiles_stripes',
    kind: 'tiles',
    price: 25,
    color: AppColors.cyan,
  ),
  Cosmetic(
    id: 'tiles_dots',
    kind: 'tiles',
    price: 25,
    color: AppColors.pink,
  ),
  Cosmetic(
    id: 'tiles_metal',
    kind: 'tiles',
    price: 25,
    color: const Color(0xFF9AA3B5),
  ),
  Cosmetic(
    id: 'victory_gold',
    kind: 'victory',
    price: 15,
    color: AppColors.yellow,
  ),
  Cosmetic(
    id: 'victory_pink',
    kind: 'victory',
    price: 15,
    color: AppColors.pink,
  ),
  Cosmetic(
    id: 'victory_mint',
    kind: 'victory',
    price: 15,
    color: AppColors.green,
  ),
  Cosmetic(
    id: 'victory_stars',
    kind: 'victory',
    price: 22,
    color: AppColors.yellow,
  ),
  Cosmetic(
    id: 'victory_bubbles',
    kind: 'victory',
    price: 22,
    color: AppColors.cyan,
  ),
  Cosmetic(
    id: 'victory_letters',
    kind: 'victory',
    price: 22,
    color: AppColors.orange,
  ),
];

const cosmeticPacks = <CosmeticPack>[
  CosmeticPack(
    id: 'pack_ocean',
    price: 40,
    color: AppColors.cyan,
    items: ['frame_cyan', 'tiles_ocean', 'victory_bubbles'],
  ),
  CosmeticPack(
    id: 'pack_candy',
    price: 40,
    color: AppColors.pink,
    items: ['frame_pink', 'tiles_candy', 'victory_stars'],
  ),
  CosmeticPack(
    id: 'pack_royal',
    price: 50,
    color: AppColors.yellow,
    items: ['frame_ornament', 'name_outline', 'victory_stars'],
  ),
];

const cosmeticKinds = [
  'pack',
  'hair',
  'hat',
  'frame',
  'name',
  'tiles',
  'victory',
];

Cosmetic? cosmeticOf(String id) {
  for (final item in cosmetics) {
    if (item.id == id) return item;
  }
  return null;
}

CosmeticPack? cosmeticPackOf(String id) {
  for (final pack in cosmeticPacks) {
    if (pack.id == id) return pack;
  }
  return null;
}

/// Confettis / particules teintés par l'effet de victoire équipé.
List<Color>? victoryColors(String id) {
  final color = cosmeticOf(id)?.color;
  if (color == null) return null;
  return [color, Color.lerp(color, AppColors.white, 0.45)!, color];
}

VictoryShape victoryShapeFor(String id) => victoryShapeOf(id);

String cosmeticKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'pack' => l10n.looksPacks,
  'hair' => l10n.looksHair,
  'hat' => l10n.looksHat,
  'frame' => l10n.looksFrame,
  'name' => l10n.looksName,
  'tiles' => l10n.looksTiles,
  _ => l10n.looksVictory,
};

String cosmeticKindHint(AppLocalizations l10n, String kind) => switch (kind) {
  'pack' => l10n.looksPacksHint,
  'hair' => l10n.looksHairHint,
  'hat' => l10n.looksHatHint,
  'frame' => l10n.looksFrameHint,
  'name' => l10n.looksNameHint,
  'tiles' => l10n.looksTilesHint,
  _ => l10n.looksVictoryHint,
};

String cosmeticLabel(AppLocalizations l10n, Cosmetic item) => switch (item.id) {
  'hair_spiky' => l10n.looksHairSpiky,
  'hair_bob' => l10n.looksHairBob,
  'hair_curly' => l10n.looksHairCurly,
  'hair_bun' => l10n.looksHairBun,
  'hat_crown' => l10n.looksHatCrown,
  'hat_cap' => l10n.looksHatCap,
  'hat_wizard' => l10n.looksHatWizard,
  'hat_party' => l10n.looksHatParty,
  'frame_ornament' => l10n.looksFrameOrnament,
  'frame_flames' => l10n.looksFrameFlames,
  'frame_stars' => l10n.looksFrameStars,
  'name_gradient' => l10n.looksNameGradient,
  'name_outline' => l10n.looksNameOutline,
  'name_badge' => l10n.looksNameBadge,
  'tiles_stripes' => l10n.looksTilesStripes,
  'tiles_dots' => l10n.looksTilesDots,
  'tiles_metal' => l10n.looksTilesMetal,
  'victory_stars' => l10n.looksVictoryStars,
  'victory_bubbles' => l10n.looksVictoryBubbles,
  'victory_letters' => l10n.looksVictoryLetters,
  'frame_gold' || 'victory_gold' => l10n.looksGold,
  'frame_pink' || 'name_rose' || 'tiles_candy' || 'victory_pink' =>
    l10n.looksPink,
  'frame_cyan' || 'tiles_ocean' => l10n.looksCyan,
  'name_violet' => l10n.looksViolet,
  'name_orange' || 'tiles_sunset' => l10n.looksOrange,
  _ => l10n.looksMint,
};

String cosmeticPackLabel(AppLocalizations l10n, CosmeticPack pack) =>
    switch (pack.id) {
      'pack_ocean' => l10n.looksPackOcean,
      'pack_candy' => l10n.looksPackCandy,
      _ => l10n.looksPackRoyal,
    };

/// Apparences du joueur, telles que le serveur les envoie.
class PlayerLook {
  const PlayerLook({
    this.owned = const [],
    this.hair = '',
    this.hat = '',
    this.frame = '',
    this.name = '',
    this.tiles = '',
    this.victory = '',
  });

  factory PlayerLook.fromJson(Map<String, dynamic> json) => PlayerLook(
    owned: [
      for (final id in json['owned'] as List? ?? const []) id as String,
    ],
    hair: json['hair'] as String? ?? '',
    hat: json['hat'] as String? ?? '',
    frame: json['frame'] as String? ?? '',
    name: json['name'] as String? ?? '',
    tiles: json['tiles'] as String? ?? '',
    victory: json['victory'] as String? ?? '',
  );

  final List<String> owned;
  final String hair;
  final String hat;
  final String frame;
  final String name;
  final String tiles;
  final String victory;

  bool owns(String id) => owned.contains(id);

  bool equipped(Cosmetic item) => switch (item.kind) {
    'hair' => hair == item.id,
    'hat' => hat == item.id,
    'frame' => frame == item.id,
    'name' => name == item.id,
    'tiles' => tiles == item.id,
    _ => victory == item.id,
  };

  /// Aperçu : si [preview] est possédé / en essai, l'équipe à la place du slot.
  PlayerLook withPreview(Cosmetic? preview) {
    if (preview == null) return this;
    return switch (preview.kind) {
      'hair' => PlayerLook(
        owned: owned,
        hair: preview.id,
        hat: hat,
        frame: frame,
        name: name,
        tiles: tiles,
        victory: victory,
      ),
      'hat' => PlayerLook(
        owned: owned,
        hair: hair,
        hat: preview.id,
        frame: frame,
        name: name,
        tiles: tiles,
        victory: victory,
      ),
      'frame' => PlayerLook(
        owned: owned,
        hair: hair,
        hat: hat,
        frame: preview.id,
        name: name,
        tiles: tiles,
        victory: victory,
      ),
      'name' => PlayerLook(
        owned: owned,
        hair: hair,
        hat: hat,
        frame: frame,
        name: preview.id,
        tiles: tiles,
        victory: victory,
      ),
      'tiles' => PlayerLook(
        owned: owned,
        hair: hair,
        hat: hat,
        frame: frame,
        name: name,
        tiles: preview.id,
        victory: victory,
      ),
      _ => PlayerLook(
        owned: owned,
        hair: hair,
        hat: hat,
        frame: frame,
        name: name,
        tiles: tiles,
        victory: preview.id,
      ),
    };
  }

  PlayerLook withPackPreview(CosmeticPack pack) {
    var next = this;
    for (final id in pack.items) {
      final item = cosmeticOf(id);
      if (item != null) next = next.withPreview(item);
    }
    return next;
  }
}
