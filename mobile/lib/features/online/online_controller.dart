import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/network/realtime_client.dart';
import '../game/data/models.dart';
import 'data/room_models.dart';

enum NoticeKind { joined, left, disconnected, reconnected, error }

class RoomNotice {
  const RoomNotice(this.kind, this.nickname);

  final NoticeKind kind;
  final String nickname;
}

/// Online state shared by the whole app: player count, open rooms and the
/// room the player is in. The server pushes the full room state on every
/// change, so this mostly keeps the latest copy.
class OnlineController extends ChangeNotifier {
  OnlineController(this.client) {
    _subscription = client.events.listen(_onEvent);
    client.addListener(notifyListeners);
  }

  final RealtimeClient client;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  final _notices = StreamController<RoomNotice>.broadcast();
  final _errors = StreamController<String>.broadcast();

  int _onlineCount = 0;
  List<RoomSummary> _rooms = const [];
  RoomState? _room;
  bool _searching = false;

  String get clientId => client.clientId;
  bool get isOnline => client.isOnline;
  int get onlineCount => _onlineCount;
  List<RoomSummary> get rooms => _rooms;
  RoomState? get room => _room;
  RoomPlayer? get me => _room?.player(clientId);

  /// Waiting for the server to put us in a room (quick match, create, join).
  bool get searching => _searching;

  Stream<RoomNotice> get notices => _notices.stream;
  Stream<String> get errors => _errors.stream;

  void quickMatch(String language) =>
      _request({'type': 'quick_match', 'language': language});

  void createRoom(RoomSettings settings) =>
      _request({'type': 'create_room', 'settings': settings.toJson()});

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

  void _request(Map<String, dynamic> message) {
    _searching = true;
    notifyListeners();
    client.send(message);
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'welcome':
        _onlineCount = event['online_count'] as int;
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
        final kind = NoticeKind.values.asNameMap()[event['kind']];
        if (kind != null) {
          _notices.add(RoomNotice(kind, event['nickname'] as String? ?? ''));
        }
        return;
      case 'error':
        _searching = false;
        _errors.add(event['code'] as String? ?? 'error');
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
