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
      _send(() => _client.get(Uri.parse('$baseUrl$path')));

  Future<Map<String, dynamic>> postJson(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send(
    () => _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body ?? {}),
    ),
  );

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) => _send(
    () => _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {'content-type': 'application/json'},
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

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
