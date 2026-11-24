import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../model/services/background_json.dart';

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

  /// A photo upload sends far more bytes than a JSON call: on a slow connection 20 s would time
  /// out every attempt of the offline queue and the listing would never get published.
  static const Duration _uploadTimeout = Duration(seconds: 90);

  final String baseUrl;
  final http.Client client;

  /// JWT sent as `Authorization: Bearer …` on every request while set.
  String? authToken;

  /// Called when the server rejects the token we sent (expired or revoked), so the app can sign out.
  void Function()? onUnauthorized;

  /// Called when a request fails before receiving an HTTP response (offline, DNS failure, socket
  /// error, timeout), so connectivity state reflects real unreachability.
  void Function()? onNetworkError;

  /// Called whenever an HTTP response arrives from the server, confirming live reachability.
  void Function()? onNetworkSuccess;

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
    }, timeout: _uploadTimeout);
  }

  Map<String, String> _headers({bool json = false}) {
    final token = authToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _send(Future<http.Response> Function() request, {Duration timeout = _timeout}) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      onNetworkError?.call();
      throw const NetworkException('The server took too long to respond.');
    } on http.ClientException catch (e) {
      onNetworkError?.call();
      throw NetworkException(e.message);
    } on SocketException catch (e) {
      onNetworkError?.call();
      throw NetworkException(e.message);
    } on HandshakeException catch (e) {
      onNetworkError?.call();
      throw NetworkException(e.message);
    } on HttpException catch (e) {
      onNetworkError?.call();
      throw NetworkException(e.message);
    } on IOException catch (e) {
      onNetworkError?.call();
      throw NetworkException(e.toString());
    }
    onNetworkSuccess?.call();
    return _processResponse(response);
  }

  /// A successful body is decoded with [decodeJson]: long answers (all the listings, a long
  /// chat) are decoded in a background isolate so the UI keeps drawing while they arrive.
  Future<dynamic> _processResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return decodeJson(response.body);
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
