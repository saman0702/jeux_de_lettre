/// Solde de pièces du joueur, tel que le serveur l'envoie après chaque gain ou
/// mise. Les points marqués en ligne se convertissent : 20 points = 1 pièce.
class WalletSnapshot {
  const WalletSnapshot({
    required this.coins,
    this.coinsGained = 0,
    this.pointsToNextCoin = pointsPerCoin,
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) => WalletSnapshot(
    coins: json['coins'] as int,
    coinsGained: json['coins_gained'] as int? ?? 0,
    pointsToNextCoin: json['points_to_next_coin'] as int? ?? pointsPerCoin,
  );

  static const pointsPerCoin = 20;

  final int coins;

  /// Pièces gagnées par l'événement qui a produit ce solde (0 pour une mise).
  final int coinsGained;

  /// Points encore nécessaires pour la prochaine pièce.
  final int pointsToNextCoin;

  /// Avancement vers la prochaine pièce, entre 0 et 1.
  double get progress => 1 - pointsToNextCoin / pointsPerCoin;
}
