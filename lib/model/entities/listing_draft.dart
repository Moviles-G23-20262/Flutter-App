import 'new_listing_data.dart';

/// What was entered on the sell screen and not published yet. It survives the app being closed
/// and is deleted once the listing is published or queued, or the user discards it.
class ListingDraft {
  final String title;
  final String description;
  final String courseCode;

  /// As typed, so a half-written "35." comes back the same.
  final String price;

  /// Enum names (`GOOD`, `BOOKS`), or null while nothing was chosen.
  final String? condition;
  final String? category;
  final List<PendingImage> photos;

  const ListingDraft({
    this.title = '',
    this.description = '',
    this.courseCode = '',
    this.price = '',
    this.condition,
    this.category,
    this.photos = const [],
  });

  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      courseCode.trim().isEmpty &&
      price.trim().isEmpty &&
      condition == null &&
      category == null &&
      photos.isEmpty;
}
