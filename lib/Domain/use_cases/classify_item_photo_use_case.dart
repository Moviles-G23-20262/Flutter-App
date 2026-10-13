import 'dart:typed_data';
import '../Entities/material_entity.dart';
import '../repositories/item_photo_classifier.dart';

/// Guesses the category of an item from its photo, so the seller does not have to pick it.
/// Returns null (never throws) when the guess is not possible; the user then picks by hand.
class ClassifyItemPhotoUseCase {
  final ItemPhotoClassifier classifier;
  ClassifyItemPhotoUseCase(this.classifier);

  Future<MaterialCategoryEnum?> execute(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) return null;
    try {
      return await classifier.classify(imageBytes);
    } catch (_) {
      return null;
    }
  }
}
