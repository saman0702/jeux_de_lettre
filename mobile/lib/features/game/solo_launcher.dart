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

  final ready = game;
  final route = PopRoute(
    builder: (_) => SoloGameScreen(
      api: backend,
      game: ready,
      apiClient: apiClient,
      challenge: challenge,
    ),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
  return true;
}
