import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_config.dart';

/// A live, bidirectional text connection (a WebSocket in the app, a fake in tests).
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

/// Keeps one WebSocket to the server open, reconnecting with backoff.
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

  /// Keeps idle connections alive through proxies; null disables (tests).
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

  /// Reconnects so the server sees the new nickname.
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
      // Ignore malformed frames.
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

  /// Closes the current socket without waiting for the close handshake,
  /// which can take seconds on a bad network.
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
