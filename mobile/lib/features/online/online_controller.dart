import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import '../../core/network/realtime_client.dart';
import '../game/data/models.dart';
import '../wallet/wallet.dart';
import '../shop/cosmetics.dart';
import 'data/room_models.dart';

enum NoticeKind {
  joined,
  left,
  disconnected,
  reconnected,
  botsJoined,
  hintUsed,
  error,
}

const _noticeKinds = {
  'joined': NoticeKind.joined,
  'left': NoticeKind.left,
  'disconnected': NoticeKind.disconnected,
  'reconnected': NoticeKind.reconnected,
  'bots_joined': NoticeKind.botsJoined,
  'hint_used': NoticeKind.hintUsed,
  'error': NoticeKind.error,
};

class RoomNotice {
  const RoomNotice(this.kind, this.nickname, {this.detail = ''});

  final NoticeKind kind;
  final String nickname;

  /// Ex. catégorie du joker (`city`, `country`…).
  final String detail;
}

class VoiceCredentials {
  const VoiceCredentials({
    required this.appId,
    required this.channel,
    required this.token,
    required this.uid,
    required this.muted,
  });

  factory VoiceCredentials.fromJson(Map<String, dynamic> json) =>
      VoiceCredentials(
        appId: json['app_id'] as String,
        channel: json['channel'] as String,
        token: json['token'] as String,
        uid: json['uid'] as int,
        muted: json['muted'] as bool? ?? false,
      );

  final String appId;
  final String channel;
  final String token;
  final int uid;
  final bool muted;
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
  final _levelUps = StreamController<int>.broadcast();
  final _publicRooms = StreamController<RoomSummary>.broadcast();
  final _voiceCredentials = StreamController<VoiceCredentials>.broadcast();
  final _voiceForceMute = StreamController<bool>.broadcast();
  final _voiceKicked = StreamController<void>.broadcast();

  final Map<Category, Completer<HintOptions>> _hintRequests = {};
  final Map<Category, Completer<HintPick>> _hintPicks = {};
  Completer<BuyHintResult>? _buyHint;
  Completer<CategoryInfo>? _categoryInfo;
  Completer<int>? _buyFreeze;
  Completer<void>? _unlockChat;

  int _onlineCount = 0;
  List<RoomSummary> _rooms = const [];
  RoomState? _room;
  bool _searching = false;
  WalletSnapshot? _wallet;
  int _avatarPreset = 0;
  String? _avatarUrl;
  PlayerLook _look = const PlayerLook();

  /// Tuiles et confettis achetés : l'appli les garde pour les parties solo.
  void Function(PlayerLook look)? onLook;

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

  /// Apparences équipées (coiffure, chapeau, cadre…).
  PlayerLook get look => _look;

  void setAvatar(int preset, String? url) {
    _avatarPreset = preset;
    _avatarUrl = url;
    notifyListeners();
  }

  void applyLook(PlayerLook look) {
    _look = look;
    onLook?.call(look);
    notifyListeners();
  }

  /// Signale la photo d'un autre joueur de la salle.
  void reportPlayer(String clientId) =>
      client.send({'type': 'report_player', 'client_id': clientId});

  /// Nouveaux niveaux atteints, pour la célébration « NIVEAU N ! ».
  Stream<int> get levelUps => _levelUps.stream;

  /// Niveau du joueur (1 tant que le serveur ne l'a pas envoyé).
  int get level => _wallet?.level ?? 1;

  /// Nouveau solde reçu par la socket ou par l'API solo.
  void applyWallet(WalletSnapshot wallet) {
    final previous = _wallet;
    _wallet = wallet;
    if (wallet.coinsGained > 0) _coinGains.add(wallet.coinsGained);
    if (previous != null && wallet.level > previous.level) {
      _levelUps.add(wallet.level);
    }
    notifyListeners();
  }

  /// En attente que le serveur nous place dans une salle (partie rapide,
  /// création, rejoindre).
  bool get searching => _searching;

  Stream<RoomNotice> get notices => _notices.stream;
  Stream<String> get errors => _errors.stream;

  /// Nouveau salon public ouvert : pour proposer « Rejoindre » sans code.
  Stream<RoomSummary> get publicRooms => _publicRooms.stream;

  Stream<VoiceCredentials> get voiceCredentials => _voiceCredentials.stream;
  Stream<bool> get voiceForceMute => _voiceForceMute.stream;
  Stream<void> get voiceKicked => _voiceKicked.stream;

  void requestVoiceJoin() => client.send({'type': 'voice_join'});

  void voiceMute(String clientId, bool muted) =>
      client.send({'type': 'voice_mute', 'client_id': clientId, 'muted': muted});

  void voiceMuteAll(bool muted) =>
      client.send({'type': 'voice_mute_all', 'muted': muted});

  void voiceExclude(String clientId) =>
      client.send({'type': 'voice_exclude', 'client_id': clientId});

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
    'answers': {for (final e in answers.entries) e.key.wire: e.value},
  });

  void watchRooms(String language) =>
      client.send({'type': 'subscribe_rooms', 'language': language});

  void unwatchRooms() => client.send({'type': 'unsubscribe_rooms'});

  /// Demande au serveur les trois propositions d'une catégorie (consomme un
  /// joker).
  Future<HintOptions> requestHint(
    int round,
    Category category, {
    bool reveal = false,
  }) {
    final completer = _hintRequests[category] = Completer<HintOptions>();
    client.send({
      'type': 'hint',
      'round': round,
      'category': category.wire,
      'reveal': reveal,
    });
    return _withTimeout(completer.future);
  }

  Future<HintPick> pickHint(int round, Category category, String choice) {
    final completer = _hintPicks[category] = Completer<HintPick>();
    client.send({
      'type': 'hint_pick',
      'round': round,
      'category': category.wire,
      'choice': choice,
    });
    return _withTimeout(completer.future);
  }

  Future<BuyHintResult> buyHint() {
    final completer = _buyHint = Completer<BuyHintResult>();
    client.send({'type': 'buy_hint'});
    return _withTimeout(completer.future);
  }

  Future<CategoryInfo> buyCategoryInfo(Category category) {
    final completer = _categoryInfo = Completer<CategoryInfo>();
    client.send({'type': 'category_info', 'category': category.wire});
    return _withTimeout(completer.future);
  }

  void freezePlayer(String targetId) =>
      client.send({'type': 'freeze', 'target': targetId});

  Future<int> buyFreeze() {
    final completer = _buyFreeze = Completer<int>();
    client.send({'type': 'buy_freeze'});
    return _withTimeout(completer.future);
  }

  void react(RoomSticker sticker) =>
      client.send({'type': 'react', 'sticker': sticker.name});

  Future<void> unlockChat() {
    final completer = _unlockChat = Completer<void>();
    client.send({'type': 'unlock_chat'});
    return _withTimeout(completer.future);
  }

  void sendChat(String text) => client.send({'type': 'chat', 'text': text});

  void voteRematch(bool vote) =>
      client.send({'type': 'rematch_vote', 'vote': vote});

  void pickLightning(String choice) =>
      client.send({'type': 'lightning_pick', 'choice': choice});

  void startBonus() => client.send({'type': 'start_bonus'});

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
    if (_buyHint case final c? when !c.isCompleted) {
      c.completeError(ApiException(code));
    }
    _buyHint = null;
    if (_categoryInfo case final c? when !c.isCompleted) {
      c.completeError(ApiException(code));
    }
    _categoryInfo = null;
    if (_buyFreeze case final c? when !c.isCompleted) {
      c.completeError(ApiException(code));
    }
    _buyFreeze = null;
    if (_unlockChat case final c? when !c.isCompleted) {
      c.completeError(ApiException(code));
    }
    _unlockChat = null;
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
        if (event['look'] case final Map<String, dynamic> look) {
          applyLook(PlayerLook.fromJson(look));
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
      case 'public_room':
        final summary = RoomSummary.fromJson(
          event['room'] as Map<String, dynamic>,
        );
        // Liste locale à jour même sans écran « Salons ».
        if (!_rooms.any((r) => r.code == summary.code)) {
          _rooms = [summary, ..._rooms];
        }
        _publicRooms.add(summary);
        notifyListeners();
        return;
      case 'room_state':
        try {
          _room = RoomState.fromJson(
            Map<String, dynamic>.from(event['room'] as Map),
            receivedAt: DateTime.now(),
          );
          _searching = false;
        } catch (e, st) {
          assert(() {
            // ignore: avoid_print
            print('room_state parse failed: $e\n$st');
            return true;
          }());
          return;
        }
      case 'left_room':
        _room = null;
        _searching = false;
      case 'notice':
        final kind = _noticeKinds[event['kind']];
        if (kind != null) {
          _notices.add(
            RoomNotice(
              kind,
              event['nickname'] as String? ?? '',
              detail: event['detail'] as String? ?? '',
            ),
          );
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
      case 'hint_bought':
        if (event['wallet'] case final Map<String, dynamic> wallet) {
          applyWallet(WalletSnapshot.fromJson(wallet));
        }
        _buyHint?.complete(BuyHintResult.fromJson(event));
        _buyHint = null;
        return;
      case 'category_info':
        if (event['wallet'] case final Map<String, dynamic> wallet) {
          applyWallet(WalletSnapshot.fromJson(wallet));
        }
        _categoryInfo?.complete(CategoryInfo.fromJson(event));
        _categoryInfo = null;
        return;
      case 'freeze_bought':
        if (event['wallet'] case final Map<String, dynamic> wallet) {
          applyWallet(WalletSnapshot.fromJson(wallet));
        }
        _buyFreeze?.complete(event['freezes_left'] as int? ?? 0);
        _buyFreeze = null;
        return;
      case 'freeze_ok':
        return;
      case 'chat_unlocked':
        if (event['wallet'] case final Map<String, dynamic> wallet) {
          applyWallet(WalletSnapshot.fromJson(wallet));
        }
        _unlockChat?.complete();
        _unlockChat = null;
        return;
      case 'voice_credentials':
        _voiceCredentials.add(VoiceCredentials.fromJson(event));
        return;
      case 'voice_force_mute':
        _voiceForceMute.add(event['muted'] as bool? ?? true);
        return;
      case 'voice_kicked':
        _voiceKicked.add(null);
        return;
      case 'error':
        final code = event['code'] as String? ?? 'error';
        if (_hintRequests.isNotEmpty ||
            _hintPicks.isNotEmpty ||
            _buyHint != null ||
            _categoryInfo != null ||
            _buyFreeze != null ||
            _unlockChat != null) {
          // Les erreurs de joker / infos sont affichées par le bouton, pas
          // comme des erreurs de salle.
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
    _levelUps.close();
    _publicRooms.close();
    _voiceCredentials.close();
    _voiceForceMute.close();
    _voiceKicked.close();
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
