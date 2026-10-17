import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_config.dart';

/// Une connexion texte bidirectionnelle en direct (une WebSocket dans l'appli,
/// une imitation dans les tests).
abstract class RealtimeConnection {
  Stream<String> get messages;
  void send(String message);
  Future<void> close();
}

typedef RealtimeConnector = Future<RealtimeConnection> Function(Uri uri);

class _WebSocketConnection implements RealtimeConnection {
  _WebSocketConnection(this._channel);

  final WebSocketChannel _channel;

  static Future<RealtimeConnection> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(const Duration(seconds: 8));
    return _WebSocketConnection(channel);
  }

  @override
  Stream<String> get messages => _channel.stream.map((m) => m.toString());

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();
}

enum RealtimeStatus { connecting, online, offline }

/// Garde une WebSocket ouverte vers le serveur, en se reconnectant avec un
/// délai croissant.
class RealtimeClient extends ChangeNotifier {
  RealtimeClient({
    required this.clientId,
    required this._nickname,
    RealtimeConnector? connector,
    this.baseUrl = apiBaseUrl,
    this.pingInterval = const Duration(seconds: 20),
  }) : _connector = connector ?? _WebSocketConnection.connect;

  final String clientId;
  final String baseUrl;

  /// Garde les connexions inactives en vie à travers les proxys ; null
  /// désactive (tests).
  final Duration? pingInterval;
  final RealtimeConnector _connector;
  final _events = StreamController<Map<String, dynamic>>.broadcast();

  String _nickname;
  RealtimeConnection? _connection;
  StreamSubscription<String>? _subscription;
  RealtimeStatus _status = RealtimeStatus.offline;
  Timer? _retryTimer;
  Timer? _pingTimer;
  int _attempt = 0;
  bool _closed = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  RealtimeStatus get status => _status;
  bool get isOnline => _status == RealtimeStatus.online;

  /// Le serveur n'a pas répondu à la dernière tentative de connexion (et pas
  /// seulement « pas encore connecté »).
  bool get unreachable => !isOnline && _attempt > 0;

  Uri get _uri {
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: {'client_id': clientId, 'nickname': _nickname},
    );
  }

  Future<void> connect() async {
    if (_closed || _status == RealtimeStatus.connecting) return;
    _retryTimer?.cancel();
    _setStatus(RealtimeStatus.connecting);
    try {
      final connection = await _connector(_uri);
      _connection = connection;
      _subscription = connection.messages.listen(
        _onMessage,
        onDone: _onLost,
        onError: (_) => _onLost(),
      );
      _attempt = 0;
      _setStatus(RealtimeStatus.online);
      final interval = pingInterval;
      if (interval != null) {
        _pingTimer = Timer.periodic(interval, (_) => send({'type': 'ping'}));
      }
    } catch (_) {
      _onLost();
    }
  }

  /// Se reconnecte pour que le serveur voie le nouveau pseudo.
  Future<void> updateNickname(String nickname) async {
    if (nickname == _nickname) return;
    _nickname = nickname;
    _drop();
    await connect();
  }

  void send(Map<String, dynamic> message) {
    if (isOnline) _connection?.send(jsonEncode(message));
  }

  void _onMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) _events.add(decoded);
    } catch (_) {
      // Ignore les trames mal formées.
    }
  }

  void _onLost() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _connection = null;
    if (_closed) return;
    _setStatus(RealtimeStatus.offline);
    final delay = Duration(seconds: [1, 2, 4, 8, 10][_attempt.clamp(0, 4)]);
    _attempt++;
    _retryTimer = Timer(delay, connect);
  }

  /// Ferme la socket actuelle sans attendre la fin de la fermeture, qui peut
  /// prendre plusieurs secondes sur un mauvais réseau.
  void _drop() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _connection?.close();
    _connection = null;
    _setStatus(RealtimeStatus.offline);
  }

  void _setStatus(RealtimeStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _retryTimer?.cancel();
    _drop();
    _events.close();
    super.dispose();
  }
}
