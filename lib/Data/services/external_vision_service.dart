import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../Domain/Entities/material_entity.dart';
import '../../Domain/repositories/item_photo_classifier.dart';

/// External service: zero-shot image classification with CLIP on the Hugging Face Inference API.
/// The photo is sent with the candidate labels and the best-scoring one becomes a category.
///
/// Every failure (no connection, timeout, HTTP error, unexpected body) returns null so the
/// user can pick the category manually; nothing here throws.
class ExternalVisionService implements ItemPhotoClassifier {
  static const String defaultEndpoint =
      'https://api-inference.huggingface.co/models/openai/clip-vit-base-patch32';
  static const Duration defaultTimeout = Duration(seconds: 20);

  /// Candidate labels sent to the model, and the category each one stands for.
  static const Map<String, MaterialCategoryEnum> labelToCategory = {
    'books': MaterialCategoryEnum.BOOKS,
    'calculators': MaterialCategoryEnum.CALCULATORS,
    'lab equipment': MaterialCategoryEnum.LAB_EQUIPMENT,
    'furniture': MaterialCategoryEnum.FURNITURE,
    'other': MaterialCategoryEnum.OTHER,
  };

  final http.Client client;
  final Duration timeout;
  final Uri _endpoint;
  final String? _token;

  ExternalVisionService({
    required this.client,
    String? apiToken,
    String endpoint = defaultEndpoint,
    this.timeout = defaultTimeout,
  })  : _endpoint = Uri.parse(endpoint),
        _token = (apiToken == null || apiToken.isEmpty) ? null : apiToken;

  @override
  Future<MaterialCategoryEnum?> classify(Uint8List imageBytes) async {
    try {
      final response = await client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              // Wait for the model to load instead of answering 503 on a cold start.
              'x-wait-for-model': 'true',
              if (_token != null) 'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'inputs': base64Encode(imageBytes),
              'parameters': {'candidate_labels': labelToCategory.keys.toList()},
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[VisionService Error] HTTP ${response.statusCode}: ${_short(response.body)}');
        return null;
      }
      final category = _bestCategory(jsonDecode(utf8.decode(response.bodyBytes)));
      if (category == null) debugPrint('[VisionService Error] No known label in: ${_short(response.body)}');
      return category;
    } catch (e) {
      debugPrint('[VisionService Error] ${e.runtimeType}: ${_short('$e')}');
      return null;
    }
  }

  static String _short(String text) => text.length <= 200 ? text : '${text.substring(0, 200)}…';

  /// The known label with the highest score in `[{label, score}, ...]`.
  static MaterialCategoryEnum? _bestCategory(Object? body) {
    if (body is! List) return null;
    MaterialCategoryEnum? best;
    var bestScore = double.negativeInfinity;
    for (final item in body) {
      if (item is! Map) continue;
      final category = labelToCategory[item['label']];
      final score = item['score'];
      if (category == null || score is! num) continue;
      if (score > bestScore) {
        bestScore = score.toDouble();
        best = category;
      }
    }
    return best;
  }
}
