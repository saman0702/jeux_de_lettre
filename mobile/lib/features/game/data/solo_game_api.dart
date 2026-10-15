import '../../../core/network/api_client.dart';
import 'models.dart';

class SoloGameApi {
  SoloGameApi(this._api);

  final ApiClient _api;

  Future<SoloGame> createGame(SoloGameSettings settings) async =>
      SoloGame.fromJson(
        await _api.postJson('/api/v1/solo/games', settings.toJson()),
      );

  Future<GameRound> startRound(String gameId) async => GameRound.fromJson(
    await _api.postJson('/api/v1/solo/games/$gameId/rounds'),
  );

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
    return (
      RoundResult.fromJson(body['round'] as Map<String, dynamic>),
      SoloGame.fromJson(body['game'] as Map<String, dynamic>),
    );
  }

  Future<HintOptions> requestHint(
    String gameId,
    int roundNumber,
    Category category,
  ) async => HintOptions.fromJson(
    await _api.postJson('/api/v1/solo/games/$gameId/rounds/$roundNumber/hint', {
      'category': category.name,
    }),
  );

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
