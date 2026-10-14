import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';

/// Error returned by the API, `code` is the server's `detail` (e.g. `round_in_progress`).
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

  /// Returns true when the API and its dependencies are healthy.
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

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
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
