import 'models.dart';

/// Ce dont une partie solo a besoin : le serveur (en ligne) ou le moteur
/// intégré à l'appli (hors ligne).
abstract class SoloBackend {
  /// Vrai quand la partie tourne sur l'appareil, sans le serveur.
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
