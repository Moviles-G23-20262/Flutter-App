import '../entities/listing_draft.dart';
import '../entities/material_entity.dart';
import '../entities/new_listing_data.dart';
import '../entities/rating_draft.dart';

// Drafts ↔ the JSON kept in shared_preferences.

Map<String, dynamic> ratingDraftToJson(RatingDraft draft) => {
      'checkedItems': draft.checkedItems.toList()..sort(),
      'receivedCondition': draft.receivedCondition?.name,
      'stars': draft.stars,
      'tags': draft.tags.toList(),
      'review': draft.review,
    };

RatingDraft ratingDraftFromJson(Map<String, dynamic> json) => RatingDraft(
      checkedItems: {for (final i in json['checkedItems'] as List? ?? const []) i as int},
      receivedCondition:
          MaterialConditionEnum.values.where((c) => c.name == json['receivedCondition']).firstOrNull,
      stars: (json['stars'] as int? ?? 0).clamp(0, 5),
      tags: {for (final t in json['tags'] as List? ?? const []) t as String},
      review: json['review'] as String? ?? '',
    );

/// The photos are files; the JSON only names them by [photoPaths].
Map<String, dynamic> listingDraftToJson(ListingDraft draft, List<String> photoPaths) => {
      'title': draft.title,
      'description': draft.description,
      'course': draft.courseCode,
      'price': draft.price,
      'condition': draft.condition,
      'category': draft.category,
      'photoPaths': photoPaths,
    };

List<String> listingDraftPhotoPaths(Map<String, dynamic> json) =>
    [for (final path in json['photoPaths'] as List? ?? const []) path as String];

/// Unknown condition or category names (written by another app version) are dropped.
ListingDraft listingDraftFromJson(Map<String, dynamic> json, List<PendingImage> photos) => ListingDraft(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      courseCode: json['course'] as String? ?? '',
      price: json['price'] as String? ?? '',
      condition: MaterialConditionEnum.values.where((c) => c.name == json['condition']).firstOrNull?.name,
      category: MaterialCategoryEnum.values.where((c) => c.name == json['category']).firstOrNull?.name,
      photos: photos,
    );
