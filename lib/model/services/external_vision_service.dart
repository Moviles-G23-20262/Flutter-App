import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../entities/material_entity.dart';
import '../repositories/item_photo_classifier.dart';

/// External service: image classification with the Google Gemini REST API (generateContent).
/// The photo is sent as base64 together with a prompt that asks for exactly one category name,
/// and the text of the answer becomes a [MaterialCategoryEnum].
///
/// Every failure (no API key, no connection, timeout, HTTP error, blocked or unexpected answer)
/// returns null so the user can pick the category manually; nothing here throws.
class ExternalVisionService implements ItemPhotoClassifier {
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// `gemini-1.5-flash` is retired (the API answers 404 for it); `gemini-flash-latest` always
  /// points to the current Flash model.
  static const String defaultModel = 'gemini-flash-latest';
  static const Duration defaultTimeout = Duration(seconds: 20);

  static const String prompt =
      'Analyze this photo of a university student item. Classify it into exactly ONE of the '
      'following categories: BOOKS, CALCULATORS, LAB_EQUIPMENT, FURNITURE, OTHER. '
      'Respond with ONLY the exact category name in uppercase, nothing else.';

  final http.Client client;
  final String model;
  final Duration timeout;
  final String? _apiKey;

  ExternalVisionService({
    required this.client,
    String? apiKey,
    this.model = defaultModel,
    this.timeout = defaultTimeout,
  }) : _apiKey = (apiKey == null || apiKey.isEmpty) ? null : apiKey;

  /// The endpoint without the key, safe to print.
  String get _publicEndpoint => '$baseUrl/$model:generateContent';

  @override
  Future<MaterialCategoryEnum?> classify(Uint8List imageBytes) async {
    final key = _apiKey;
    if (key == null) {
      _log('no API key: run the app with --dart-define-from-file=config/development.json '
          '(VISION_API_KEY). Skipping the request.');
      return null;
    }

    final mimeType = _mimeType(imageBytes);
    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Encode(imageBytes)},
            },
          ],
        },
      ],
    };

    // Debug trace of the exchange. The API key is never printed.
    debugPrint('[VisionService] POST $_publicEndpoint?key=<hidden> | ${imageBytes.length} bytes, $mimeType');
    try {
      final response = await client
          .post(
            Uri.parse('$_publicEndpoint?key=$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      debugPrint('[VisionService] status: ${response.statusCode} ${_meaning(response.statusCode)}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log('response body: ${_short(response.body, 800)}');
        return null;
      }

      final text = _answerText(jsonDecode(utf8.decode(response.bodyBytes)));
      debugPrint('[VisionService] answer: ${text == null ? '<none>' : '"$text"'}');
      final category = text == null ? null : categoryFromAnswer(text);
      if (category == null) {
        _log('could not map the answer to a category. Response: ${_short(response.body, 800)}');
      } else {
        debugPrint('[VisionService] detected category: ${category.name}');
      }
      return category;
    } catch (e, stack) {
      _log('$e');
      _log('exception type: ${e.runtimeType}');
      debugPrint('$stack');
      return null;
    }
  }

  /// Maps the model's answer to a category: cleans whitespace, quotes and punctuation, then
  /// accepts the exact name (`LAB_EQUIPMENT`, also written `lab equipment`). Null if unknown.
  static MaterialCategoryEnum? categoryFromAnswer(String answer) {
    final cleaned = answer
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'[^A-Z_]'), '')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    for (final category in MaterialCategoryEnum.values) {
      if (category.name == cleaned) return category;
    }
    return null;
  }

  /// The text parts of the first candidate, joined, or null when Gemini returned none
  /// (blocked prompt, empty answer, unexpected shape).
  static String? _answerText(Object? body) {
    if (body is! Map) return null;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    final content = first is Map ? first['content'] : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;
    final text = parts.whereType<Map>().map((p) => p['text']).whereType<String>().join();
    return text.trim().isEmpty ? null : text.trim();
  }

  /// PNG and WebP photos from the gallery are labelled as such; anything else is sent as JPEG,
  /// which is what the camera produces.
  static String _mimeType(Uint8List bytes) {
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length > 12 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static void _log(String message) => debugPrint('[VisionService Error] $message');

  /// What the usual failure codes mean for this API, to read the log at a glance.
  static String _meaning(int status) {
    if (status >= 200 && status < 300) return '(OK)';
    switch (status) {
      case 400:
        return '(bad request: payload rejected or the API key is not valid)';
      case 403:
        return '(forbidden: the API key cannot use this API)';
      case 404:
        return '(model not found: it may have been retired, check the model name)';
      case 429:
        return '(rate limited / free quota exhausted)';
      case 503:
        return '(model overloaded, try again)';
      default:
        return '';
    }
  }

  static String _short(String text, [int max = 200]) =>
      text.length <= max ? text : '${text.substring(0, max)}…';
}
