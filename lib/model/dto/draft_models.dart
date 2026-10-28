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

class RegistrationDraft {
  final String fullName;
  final String email;
  final String major;
  final String? faculty;

  const RegistrationDraft({
    this.fullName = '',
    this.email = '',
    this.major = '',
    this.faculty,
  });

  bool get isEmpty => fullName.isEmpty && email.isEmpty && major.isEmpty;
}

Map<String, dynamic> registrationDraftToJson(RegistrationDraft draft) => {
      'fullName': draft.fullName,
      'email': draft.email,
      'major': draft.major,
      if (draft.faculty != null) 'faculty': draft.faculty,
      'savedAt': DateTime.now().toIso8601String(),
    };

RegistrationDraft registrationDraftFromJson(Map<String, dynamic> json) => RegistrationDraft(
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      major: json['major'] as String? ?? '',
      faculty: json['faculty'] as String?,
    );

class SellDraft {
  final String title;
  final String description;
  final String? courseCode;
  final double? price;
  final MaterialConditionEnum? condition;
  final MaterialCategoryEnum? category;
  final List<String> photoPaths;

  const SellDraft({
    this.title = '',
    this.description = '',
    this.courseCode,
    this.price,
    this.condition,
    this.category,
    this.photoPaths = const [],
  });

  bool get isEmpty =>
      title.isEmpty &&
      description.isEmpty &&
      (courseCode == null || courseCode!.isEmpty) &&
      price == null &&
      photoPaths.isEmpty;
}

Map<String, dynamic> sellDraftToJson(SellDraft draft) => {
      'title': draft.title,
      'description': draft.description,
      'courseCode': draft.courseCode,
      'price': draft.price,
      'condition': draft.condition?.name,
      'category': draft.category?.name,
      'photoPaths': draft.photoPaths,
      'savedAt': DateTime.now().toIso8601String(),
    };

SellDraft sellDraftFromJson(Map<String, dynamic> json) => SellDraft(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      courseCode: json['courseCode'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      condition: MaterialConditionEnum.values
          .where((c) => c.name == json['condition'])
          .firstOrNull,
      category: MaterialCategoryEnum.values
          .where((c) => c.name == json['category'])
          .firstOrNull,
      photoPaths: (json['photoPaths'] as List?)?.map((e) => e as String).toList() ?? const [],
    );
