import 'dart:typed_data';

import 'material_entity.dart';

/// A photo the user picked, not uploaded yet.
class PendingImage {
  final Uint8List bytes;
  final String filename;

  const PendingImage({required this.bytes, required this.filename});
}

/// What the "List New Item" form collects.
class NewListingData {
  final String title;
  final String description;
  final String? courseCode;
  final double price;
  final MaterialConditionEnum condition;
  final MaterialCategoryEnum category;
  final List<PendingImage> images;

  const NewListingData({
    required this.title,
    required this.description,
    this.courseCode,
    required this.price,
    required this.condition,
    required this.category,
    this.images = const [],
  });
}
