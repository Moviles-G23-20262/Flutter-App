import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// The server answered with a non-2xx status.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The request never got an answer (offline, DNS failure, timeout…).
class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class ApiClient {
  static const Duration _timeout = Duration(seconds: 20);

  final String baseUrl;
  final http.Client client;

  /// JWT sent as `Authorization: Bearer …` on every request while set.
  String? authToken;

  /// Called when the server rejects the token we sent (expired or revoked), so the app can sign out.
  void Function()? onUnauthorized;

  ApiClient({required String baseUrl, required this.client})
      // Config files may end with "/", which would turn "$baseUrl/auth" into "//auth".
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  Future<dynamic> get(String endpoint) {
    return _send(() => client.get(Uri.parse('$baseUrl$endpoint'), headers: _headers()));
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) {
    return _send(
      () => client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(json: true),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> patch(String endpoint, {required Map<String, dynamic> body}) {
    return _send(
      () => client.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String endpoint) {
    return _send(() => client.delete(Uri.parse('$baseUrl$endpoint'), headers: _headers()));
  }

  /// Uploads one file as `multipart/form-data` under [field].
  Future<dynamic> postFile(
    String endpoint, {
    required String field,
    required List<int> bytes,
    required String filename,
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'))
        ..headers.addAll(_headers())
        ..files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
      return http.Response.fromStream(await client.send(request));
    });
  }

  Map<String, String> _headers({bool json = false}) {
    final token = authToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const NetworkException('The server took too long to respond.');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null;
    }
    if (response.statusCode == 401 && authToken != null) onUnauthorized?.call();
    throw ApiException(response.statusCode, _errorMessage(response));
  }

  /// NestJS errors look like `{"message": "text" | ["text", …], "error": "…"}`.
  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String) return message;
        if (message is List) return message.join('\n');
      }
    } on FormatException {
      // Not JSON (e.g. an HTML error page from the host); fall through.
    }
    return response.reasonPhrase ?? 'Request failed';
  }
}
