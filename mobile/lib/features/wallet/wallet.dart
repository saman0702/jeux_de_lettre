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
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) => WalletSnapshot(
    coins: json['coins'] as int,
    coinsGained: json['coins_gained'] as int? ?? 0,
    pointsToNextCoin: json['points_to_next_coin'] as int? ?? pointsPerCoin,
    level: json['level'] as int? ?? 1,
    levelXp: json['level_xp'] as int? ?? 0,
    levelXpNeeded: json['level_xp_needed'] as int? ?? 100,
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
