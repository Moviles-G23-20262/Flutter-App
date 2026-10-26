import 'dart:typed_data';
import '../entities/material_entity.dart';

abstract class ItemPhotoClassifier {
  /// The category the photo most likely shows, or null when it cannot be told
  /// (no connection, the service failed, nothing recognised). Never throws.
  Future<MaterialCategoryEnum?> classify(Uint8List imageBytes);
}
