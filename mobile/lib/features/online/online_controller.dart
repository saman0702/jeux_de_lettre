import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../game/data/models.dart';
import '../wallet/wallet.dart';
import 'data/room_models.dart';

enum NoticeKind { joined, left, disconnected, reconnected, botsJoined, error }

const _noticeKinds = {
  'joined': NoticeKind.joined,
  'left': NoticeKind.left,
  'disconnected': NoticeKind.disconnected,
  'reconnected': NoticeKind.reconnected,
  'bots_joined': NoticeKind.botsJoined,
  'error': NoticeKind.error,
};

class RoomNotice {
  const RoomNotice(this.kind, this.nickname);

  final NoticeKind kind;
  final String nickname;
}

/// État en ligne partagé par toute l'appli : nombre de joueurs, salons ouverts
/// et salle où se trouve le joueur. Le serveur envoie l'état complet de la
/// salle à chaque changement : on garde surtout la dernière copie.
class OnlineController extends ChangeNotifier {
  OnlineController(this.client) {
    _subscription = client.events.listen(_onEvent);
    client.addListener(notifyListeners);
  }

  final RealtimeClient client;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _notices = StreamController<RoomNotice>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _coinGains = StreamController<int>.broadcast();

  final Map<Category, Completer<HintOptions>> _hintRequests = {};
  final Map<Category, Completer<HintPick>> _hintPicks = {};

  int _onlineCount = 0;
  List<RoomSummary> _rooms = const [];
  RoomState? _room;
  bool _searching = false;
  WalletSnapshot? _wallet;
  int _avatarPreset = 0;
  String? _avatarUrl;

  String get clientId => client.clientId;
  bool get isOnline => client.isOnline;
  int get onlineCount => _onlineCount;
  List<RoomSummary> get rooms => _rooms;
  RoomState? get room => _room;
  RoomPlayer? get me => _room?.player(clientId);

  /// Solde de pièces connu (null tant que le serveur ne l'a pas envoyé).
  WalletSnapshot? get wallet => _wallet;

  /// Pièces gagnées, pour l'animation « +1 pièce ».
  Stream<int> get coinGains => _coinGains.stream;

  /// Mon avatar : personnage dessiné, ou photo dessinée si [avatarUrl].
  int get avatarPreset => _avatarPreset;
  String? get avatarUrl => _avatarUrl;

  void setAvatar(int preset, String? url) {
    _avatarPreset = preset;
    _avatarUrl = url;
    notifyListeners();
  }

  /// Signale la photo d'un autre joueur de la salle.
  void reportPlayer(String clientId) =>
      client.send({'type': 'report_player', 'client_id': clientId});

  /// Nouveau solde reçu par la socket ou par l'API solo.
  void applyWallet(WalletSnapshot wallet) {
    _wallet = wallet;
    if (wallet.coinsGained > 0) _coinGains.add(wallet.coinsGained);
    notifyListeners();
  }

  /// En attente que le serveur nous place dans une salle (partie rapide,
  /// création, rejoindre).
  bool get searching => _searching;

  Stream<RoomNotice> get notices => _notices.stream;
  Stream<String> get errors => _errors.stream;

  void quickMatch(String language) =>
      _request({'type': 'quick_match', 'language': language});

  /// Avec [bots] > 0, la salle est complétée par des adversaires ordinateur et
  /// la partie démarre aussitôt.
  void createRoom(
    RoomSettings settings, {
    int bots = 0,
    Difficulty botLevel = Difficulty.normal,
  }) => _request({
    'type': 'create_room',
    'settings': settings.toJson(),
    if (bots > 0) 'bots': {'count': bots, 'level': botLevel.name},
  });

  void addBot(Difficulty level) =>
      client.send({'type': 'add_bot', 'level': level.name});

  void removeBot(String clientId) =>
      client.send({'type': 'remove_bot', 'client_id': clientId});

  void joinRoom(String code) =>
      _request({'type': 'join_room', 'code': code.trim().toUpperCase()});

  void leaveRoom() {
    client.send({'type': 'leave_room'});
    _room = null;
    _searching = false;
    notifyListeners();
  }

  void setReady(bool ready) =>
      client.send({'type': 'set_ready', 'ready': ready});

  void submit(int round, Map<Category, String> answers) => client.send({
    'type': 'submit',
    'round': round,
    'answers': {for (final e in answers.entries) e.key.name: e.value},
  });

  void watchRooms(String language) =>
      client.send({'type': 'subscribe_rooms', 'language': language});

  void unwatchRooms() => client.send({'type': 'unsubscribe_rooms'});

  /// Demande au serveur les quatre propositions d'une catégorie (consomme un
  /// joker).
  Future<HintOptions> requestHint(int round, Category category) {
    final completer = _hintRequests[category] = Completer<HintOptions>();
    client.send({'type': 'hint', 'round': round, 'category': category.name});
    return _withTimeout(completer.future);
  }

  Future<HintPick> pickHint(int round, Category category, String choice) {
    final completer = _hintPicks[category] = Completer<HintPick>();
    client.send({
      'type': 'hint_pick',
      'round': round,
      'category': category.name,
      'choice': choice,
    });
    return _withTimeout(completer.future);
  }

  Future<T> _withTimeout<T>(Future<T> future) => future.timeout(
    const Duration(seconds: 8),
    onTimeout: () => throw ApiException('network_error'),
  );

  void _failPendingHints(String code) {
    for (final c in [..._hintRequests.values, ..._hintPicks.values]) {
      if (!c.isCompleted) c.completeError(ApiException(code));
    }
    _hintRequests.clear();
    _hintPicks.clear();
  }

  void _request(Map<String, dynamic> message) {
    _searching = true;
    notifyListeners();
    client.send(message);
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'welcome':
        _onlineCount = event['online_count'] as int;
        if (event['wallet'] case final Map<String, dynamic> wallet) {
          _wallet = WalletSnapshot.fromJson(wallet);
        }
        if (event['avatar'] case final Map<String, dynamic> avatar) {
          _avatarPreset = avatar['preset'] as int? ?? 0;
          _avatarUrl = avatar['url'] as String?;
        }
      case 'reported':
        // Accusé de réception : le message est affiché dès l'envoi.
        return;
      case 'wallet':
        applyWallet(WalletSnapshot.fromJson(event));
        return;
      case 'online_count':
        _onlineCount = event['count'] as int;
      case 'room_list':
        _rooms = [
          for (final r in event['rooms'] as List)
            RoomSummary.fromJson(r as Map<String, dynamic>),
        ];
      case 'room_state':
        _room = RoomState.fromJson(event['room'] as Map<String, dynamic>);
        _searching = false;
      case 'left_room':
        _room = null;
        _searching = false;
      case 'notice':
        final kind = _noticeKinds[event['kind']];
        if (kind != null) {
          _notices.add(RoomNotice(kind, event['nickname'] as String? ?? ''));
        }
        return;
      case 'hint':
        final options = HintOptions.fromJson(event);
        _hintRequests.remove(options.category)?.complete(options);
        return;
      case 'hint_result':
        final pick = HintPick.fromJson(event);
        _hintPicks.remove(pick.category)?.complete(pick);
        return;
      case 'error':
        final code = event['code'] as String? ?? 'error';
        if (_hintRequests.isNotEmpty || _hintPicks.isNotEmpty) {
          // Les erreurs de joker sont affichées par le bouton joker, pas comme
          // des erreurs de salle.
          _failPendingHints(code);
          return;
        }
        _searching = false;
        _errors.add(code);
      default:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    client.removeListener(notifyListeners);
    _notices.close();
    _errors.close();
    _coinGains.close();
    super.dispose();
  }
}

class OnlineScope extends InheritedWidget {
  const OnlineScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final OnlineController controller;

  static OnlineController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnlineScope>()!.controller;

  @override
  bool updateShouldNotify(OnlineScope oldWidget) =>
      controller != oldWidget.controller;
}
