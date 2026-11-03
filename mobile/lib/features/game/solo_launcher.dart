import 'package:flutter/material.dart';

import '../../animations/transitions/pop_route.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../online/online_controller.dart';
import 'data/challenge.dart';
import 'data/models.dart';
import 'data/solo_backend.dart';
import 'data/solo_game_api.dart';
import 'offline/offline_dictionary.dart';
import 'offline/offline_engine.dart';
import 'solo_draft.dart';
import 'solo_game_screen.dart';
import 'widgets/labels.dart';

/// Crée une partie solo sur le serveur (les points comptent pour les pièces
/// et le niveau) ou, sans connexion, sur le téléphone, puis ouvre l'écran de
/// jeu. Renvoie faux si la partie n'a pas pu démarrer.
Future<bool> launchSoloGame(
  BuildContext context, {
  required ApiClient apiClient,
  required SoloGameSettings settings,
  SoloChallenge? challenge,
  bool replace = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final online = OnlineScope.of(context);
  final api = SoloGameApi(apiClient, onWallet: online.applyWallet);

  SoloBackend backend = api;
  SoloGame? game;
  // Serveur déjà injoignable : inutile de l'attendre, on joue tout de suite
  // sur l'appareil.
  if (!online.client.unreachable) {
    try {
      game = await api.createGame(settings);
    } on ApiException catch (e) {
      if (e.code != 'network_error') {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMessage(l10n, e.code))),
        );
        return false;
      }
    }
  }
  if (game == null) {
    // Pas de serveur : toute la partie tourne sur l'appareil.
    backend = OfflineSoloBackend(await OfflineDictionary.load());
    game = await backend.createGame(settings);
    messenger.showSnackBar(SnackBar(content: Text(l10n.offlineModeNotice)));
  }

  // Nouvelle partie : abandonne un éventuel brouillon en pause.
  await SoloDraftStore.clear();

  final ready = game;
  final route = PopRoute(
    builder: (_) => SoloGameScreen(
      api: backend,
      game: ready,
      apiClient: apiClient,
      challenge: challenge,
      settings: settings,
    ),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
  return true;
}

/// Reprend une partie solo Geo mise en pause après une manche.
Future<bool> resumeSoloGame(
  BuildContext context, {
  required ApiClient apiClient,
  required SoloDraft draft,
  bool replace = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final online = OnlineScope.of(context);
  final api = SoloGameApi(apiClient, onWallet: online.applyWallet);

  SoloBackend backend;
  SoloGame game;
  List<RoundResult> results;

  if (draft.offline) {
    final offline = OfflineSoloBackend(await OfflineDictionary.load());
    game = await offline.restorePaused(
      id: draft.game.id,
      settings: draft.settings,
      letters: draft.letters,
      usedKeys: draft.usedKeys,
      hintsUsed: draft.hintsUsed,
      totalScore: draft.game.totalScore,
      roundsPlayed: draft.game.roundsPlayed,
    );
    results = draft.results;
    backend = offline;
  } else {
    if (online.client.unreachable) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.iqResumeNeedsOnline)));
      return false;
    }
    try {
      final fetched = await api.getGame(draft.game.id);
      game = fetched.$1;
      results = fetched.$2.isEmpty ? draft.results : fetched.$2;
      backend = api;
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(l10n, e.code))),
      );
      await SoloDraftStore.clear();
      return false;
    }
  }

  if (game.isFinished) {
    await SoloDraftStore.clear();
    messenger.showSnackBar(SnackBar(content: Text(l10n.iqNewGameMessage)));
    return false;
  }

  final route = PopRoute(
    builder: (_) => SoloGameScreen(
      api: backend,
      game: game,
      apiClient: apiClient,
      priorResults: results,
      settings: draft.settings,
    ),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
  return true;
}
