import '../../core/network/api_client.dart';
import '../../core/settings/app_settings.dart';
import '../online/online_controller.dart';
import 'profile_api.dart';

/// Garde l'avatar du téléphone et celui du serveur d'accord : un personnage
/// choisi hors ligne est envoyé dès la reconnexion, et l'avatar du serveur est
/// mémorisé pour s'afficher hors ligne.
class AvatarSync {
  AvatarSync({
    required this.settings,
    required this.online,
    required ApiClient api,
  }) : _profile = ProfileApi(api, online.clientId) {
    // Hors ligne au démarrage : on montre le dernier avatar connu.
    online.setAvatar(settings.avatarPreset, null);
    online.addListener(_onOnlineChanged);
  }

  final AppSettings settings;
  final OnlineController online;
  final ProfileApi _profile;
  bool _sending = false;
  bool _wasOnline = false;

  Future<void> _onOnlineChanged() async {
    final connected = online.isOnline;
    final justConnected = connected && !_wasOnline;
    _wasOnline = connected;
    if (!connected) return;
    if (settings.avatarPending) {
      // Le serveur ne connaît pas encore le dernier choix : on garde celui du
      // téléphone à l'écran et on l'envoie.
      if (online.avatarPreset != settings.avatarPreset ||
          online.avatarUrl != null) {
        online.setAvatar(settings.avatarPreset, null);
      }
      if (justConnected) await _push();
      return;
    }
    if (online.avatarUrl == null &&
        online.avatarPreset != settings.avatarPreset) {
      settings.setAvatarPreset(online.avatarPreset, pending: false);
    }
  }

  Future<void> _push() async {
    if (_sending) return;
    _sending = true;
    final preset = settings.avatarPreset;
    try {
      final avatar = await _profile.choosePreset(preset);
      // Un autre choix a pu être fait pendant l'envoi.
      if (settings.avatarPreset == preset) {
        settings.setAvatarPreset(preset, pending: false);
        online.setAvatar(avatar.preset, avatar.url);
      }
    } on ApiException {
      // Réessayé à la prochaine reconnexion.
    } finally {
      _sending = false;
    }
  }

  void dispose() => online.removeListener(_onOnlineChanged);
}
