import 'models.dart';

/// What a solo game needs: the server (online) or the in-app engine (offline).
abstract class SoloBackend {
  /// True when the game runs on the device, without the server.
  bool get offline;

  Future<SoloGame> createGame(SoloGameSettings settings);
  Future<GameRound> startRound(String gameId);
  Future<(RoundResult, SoloGame)> submit(
    String gameId,
    int roundNumber,
    Map<Category, String> answers,
  );
  Future<HintOptions> requestHint(
    String gameId,
    int roundNumber,
    Category category,
  );
  Future<HintPick> pickHint(
    String gameId,
    int roundNumber,
    Category category,
    String choice,
  );
}
