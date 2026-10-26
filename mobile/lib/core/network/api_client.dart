import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';

/// Erreur renvoyée par l'API ; `code` est le `detail` du serveur (ex.
/// `round_in_progress`).
class ApiException implements Exception {
  ApiException(this.code, [this.statusCode]);

  final String code;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $code)';
}

class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiBaseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// Jeton secret de l'appli (voir AppSettings.clientToken), envoyé avec
  /// chaque requête : le serveur refuse d'agir sur un profil sans lui.
  static String? clientToken;

  static Map<String, String> get _auth => {
    if (clientToken != null) 'X-Client-Token': clientToken!,
  };

  static const _timeout = Duration(seconds: 10);

  /// Renvoie vrai quand l'API et ses dépendances répondent.
  Future<bool> checkHealth() async {
    try {
      final body = await getJson('/health');
      return body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getJson(String path) =>
      _send(() => _client.get(Uri.parse('$baseUrl$path'), headers: _auth));

  /// Pour les réponses qui sont une liste JSON.
  Future<List<dynamic>> getJsonList(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: _auth)
          .timeout(_timeout);
    } catch (_) {
      throw ApiException('network_error');
    }
    if (response.statusCode >= 400) {
      throw ApiException('http_${response.statusCode}', response.statusCode);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? body,
    Duration timeout = _timeout,
  ]) => _send(
    () => _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'content-type': 'application/json', ..._auth},
      body: jsonEncode(body ?? {}),
    ),
    timeout: timeout,
  );

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) => _send(
    () => _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {'content-type': 'application/json', ..._auth},
      body: jsonEncode(body),
    ),
  );

  /// Envoie un fichier en multipart (champ [field]).
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) => _send(() async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers.addAll(_auth)
      ..files.add(
        http.MultipartFile.fromBytes(field, bytes, filename: filename),
      );
    return http.Response.fromStream(await _client.send(request));
  }, timeout: const Duration(seconds: 30));

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _timeout,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } catch (_) {
      throw ApiException('network_error');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException('http_${response.statusCode}', response.statusCode);
    }
    if (response.statusCode >= 400) {
      final detail = decoded['detail'];
      throw ApiException(
        detail is String ? detail : 'http_${response.statusCode}',
        response.statusCode,
      );
    }
    return decoded;
  }
}
