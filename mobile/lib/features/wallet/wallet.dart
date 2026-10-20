/// Solde de pièces du joueur, tel que le serveur l'envoie après chaque gain ou
/// mise. Les points marqués en ligne se convertissent : 20 points = 1 pièce.
class WalletSnapshot {
  const WalletSnapshot({
    required this.coins,
    this.coinsGained = 0,
    this.pointsToNextCoin = pointsPerCoin,
    this.level = 1,
    this.levelXp = 0,
    this.levelXpNeeded = 100,
    this.adsRemoved = false,
    this.passExpiresAt,
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) => WalletSnapshot(
    coins: json['coins'] as int,
    coinsGained: json['coins_gained'] as int? ?? 0,
    pointsToNextCoin: json['points_to_next_coin'] as int? ?? pointsPerCoin,
    level: json['level'] as int? ?? 1,
    levelXp: json['level_xp'] as int? ?? 0,
    levelXpNeeded: json['level_xp_needed'] as int? ?? 100,
    adsRemoved: json['ads_removed'] as bool? ?? false,
    passExpiresAt: json['pass_expires_at'] == null
        ? null
        : DateTime.parse(json['pass_expires_at'] as String),
  );

  /// Achat « Sans pub ».
  final bool adsRemoved;

  /// Fin de la période payée de l'abonnement Pass.
  final DateTime? passExpiresAt;

  bool passActive([DateTime? now]) =>
      passExpiresAt != null && passExpiresAt!.isAfter(now ?? DateTime.now());

  WalletSnapshot copyWith({
    int? coins,
    int? coinsGained,
    bool? adsRemoved,
    DateTime? passExpiresAt,
  }) => WalletSnapshot(
    coins: coins ?? this.coins,
    coinsGained: coinsGained ?? 0,
    pointsToNextCoin: pointsToNextCoin,
    level: level,
    levelXp: levelXp,
    levelXpNeeded: levelXpNeeded,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    passExpiresAt: passExpiresAt ?? this.passExpiresAt,
  );

  static const pointsPerCoin = 20;

  final int coins;

  /// Pièces gagnées par l'événement qui a produit ce solde (0 pour une mise).
  final int coinsGained;

  /// Points encore nécessaires pour la prochaine pièce.
  final int pointsToNextCoin;

  /// Avancement vers la prochaine pièce, entre 0 et 1.
  double get progress => 1 - pointsToNextCoin / pointsPerCoin;

  /// Niveau du joueur : il monte avec les points marqués en ligne.
  final int level;
  final int levelXp;
  final int levelXpNeeded;

  /// Avancement vers le niveau suivant, entre 0 et 1.
  double get levelProgress =>
      levelXpNeeded == 0 ? 0 : (levelXp / levelXpNeeded).clamp(0.0, 1.0);
}
