import '../entities/material_entity.dart';
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
