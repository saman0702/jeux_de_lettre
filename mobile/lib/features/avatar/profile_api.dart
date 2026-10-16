import '../../core/network/api_client.dart';

/// Avatar renvoyé par le serveur après un changement.
typedef AvatarChoice = ({int preset, String? url});

/// Profil du joueur sur le serveur : avatar dessiné ou photo.
class ProfileApi {
  ProfileApi(this._api, this.clientId);

  final ApiClient _api;
  final String clientId;

  AvatarChoice _avatar(Map<String, dynamic> json) => (
    preset: json['avatar_preset'] as int,
    url: json['avatar_url'] as String?,
  );

  Future<AvatarChoice> choosePreset(int preset) async => _avatar(
    await _api.putJson('/api/v1/profiles/$clientId', {'avatar_preset': preset}),
  );

  /// Le serveur transforme la photo en dessin avant de la garder.
  Future<AvatarChoice> uploadPhoto(List<int> bytes, String filename) async =>
      _avatar(
        await _api.uploadBytes(
          '/api/v1/profiles/$clientId/avatar',
          field: 'photo',
          bytes: bytes,
          filename: filename,
        ),
      );
}
