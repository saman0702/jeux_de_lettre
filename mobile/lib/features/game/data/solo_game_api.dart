import 'package:flutter/foundation.dart' show ValueChanged;

import '../../../core/network/api_client.dart';
import '../../wallet/wallet.dart';
import 'models.dart';
import 'solo_backend.dart';

/// Parties solo jouées sur le serveur (par défaut quand on est en ligne).
class SoloGameApi implements SoloBackend {
  SoloGameApi(this._api, {this.onWallet});

  final ApiClient _api;

  /// Reçoit le nouveau solde de pièces après chaque manche.
  final ValueChanged<WalletSnapshot>? onWallet;

  @override
  bool get offline => false;

  @override
  Future<SoloGame> createGame(SoloGameSettings settings) async =>
      SoloGame.fromJson(
        await _api.postJson('/api/v1/solo/games', settings.toJson()),
      );

  @override
  Future<GameRound> startRound(String gameId) async => GameRound.fromJson(
    await _api.postJson('/api/v1/solo/games/$gameId/rounds'),
  );

  @override
  Future<(RoundResult, SoloGame)> submit(
    String gameId,
    int roundNumber,
    Map<Category, String> answers,
  ) async {
    final body = await _api.postJson(
      '/api/v1/solo/games/$gameId/rounds/$roundNumber/submit',
      {
        'answers': {for (final e in answers.entries) e.key.name: e.value},
      },
    );
    if (body['wallet'] case final Map<String, dynamic> wallet) {
      onWallet?.call(WalletSnapshot.fromJson(wallet));
    }
    return (
      RoundResult.fromJson(body['round'] as Map<String, dynamic>),
      SoloGame.fromJson(body['game'] as Map<String, dynamic>),
    );
  }

  @override
  Future<HintOptions> requestHint(
    String gameId,
    int roundNumber,
    Category category,
  ) async => HintOptions.fromJson(
    await _api.postJson('/api/v1/solo/games/$gameId/rounds/$roundNumber/hint', {
      'category': category.name,
    }),
  );

  @override
  Future<HintPick> pickHint(
    String gameId,
    int roundNumber,
    Category category,
    String choice,
  ) async => HintPick.fromJson(
    await _api.postJson(
      '/api/v1/solo/games/$gameId/rounds/$roundNumber/hint/pick',
      {'category': category.name, 'choice': choice},
    ),
  );
}
