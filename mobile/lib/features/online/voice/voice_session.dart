import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Session Agora partagée pour le salon (partie + podium).
class VoiceSession extends ChangeNotifier {
  VoiceSession._();

  static final VoiceSession instance = VoiceSession._();

  /// Compat : les panels existants peuvent encore faire `VoiceSession()`.
  factory VoiceSession() => instance;

  RtcEngine? _engine;
  bool _joined = false;
  bool _micOn = false;
  bool _forceMuted = false;
  bool _excluded = false;
  String? _error;

  bool get joined => _joined;
  bool get micOn => _micOn && !_forceMuted;
  bool get forceMuted => _forceMuted;
  bool get excluded => _excluded;
  String? get error => _error;

  /// Micro utilisable (connecté et pas coupé par l'hôte).
  bool get canToggleMic => _engine != null && _joined && !_forceMuted;

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> join({
    required String appId,
    required String channel,
    required String token,
    required int uid,
    bool startMuted = false,
  }) async {
    if (_excluded) {
      _error = 'voice_excluded';
      notifyListeners();
      return;
    }
    if (!await _ensureMicPermission()) {
      _error = 'mic_denied';
      notifyListeners();
      return;
    }
    await leave();
    _error = null;
    _forceMuted = startMuted;
    final engine = createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _joined = true;
          // Réapplique le mute après le join (Agora peut réactiver le micro).
          unawaited(_applyMic(_micOn && !_forceMuted));
          notifyListeners();
        },
        onError: (err, msg) {
          _error = err.name;
          notifyListeners();
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateFailed ||
              state == ConnectionStateType.connectionStateDisconnected) {
            _joined = false;
            notifyListeners();
          }
        },
      ),
    );
    await engine.enableAudio();
    await engine.setDefaultAudioRouteToSpeakerphone(true);
    // Micro coupé dès le départ si demandé.
    _micOn = !_forceMuted;
    await engine.enableLocalAudio(_micOn);
    await engine.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishMicrophoneTrack: _micOn,
        autoSubscribeAudio: true,
      ),
    );
    _joined = true;
    await _applyMic(_micOn);
    notifyListeners();
  }

  Future<void> setMicOn(bool on) async {
    if (_forceMuted) return;
    if (_engine == null) return;
    await _applyMic(on);
  }

  Future<void> applyForceMute(bool muted) async {
    if (_forceMuted == muted) {
      if (muted && _micOn) await _applyMic(false);
      return;
    }
    _forceMuted = muted;
    if (muted) {
      await _applyMic(false);
    } else {
      // L'hôte a rendu le micro : reste coupé jusqu'à ce que le joueur rouvre.
      notifyListeners();
    }
  }

  Future<void> _applyMic(bool on) async {
    // Force mute hôte : toujours coupé côté Agora.
    final publish = on && !_forceMuted;
    _micOn = publish;
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.muteLocalAudioStream(!publish);
        await engine.enableLocalAudio(publish);
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(publishMicrophoneTrack: publish),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  void markExcluded() {
    _excluded = true;
    leave();
  }

  Future<void> leave() async {
    final engine = _engine;
    _engine = null;
    _joined = false;
    _micOn = false;
    if (engine != null) {
      try {
        await engine.leaveChannel();
        await engine.release();
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Coupe le canal en quittant la salle (singleton : pas de dispose).
  Future<void> resetForRoomLeave() async {
    _excluded = false;
    _forceMuted = false;
    _error = null;
    await leave();
  }
}
