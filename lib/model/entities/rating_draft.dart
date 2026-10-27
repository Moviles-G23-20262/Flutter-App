import 'material_entity.dart';

/// What was entered on the complete-exchange screen and not sent yet: the item check (buyer) and
/// the rating. It survives the app being closed and is deleted once the rating is sent or queued.
class RatingDraft {
  /// Indexes of the checklist items that were ticked.
  final Set<int> checkedItems;
  final MaterialConditionEnum? receivedCondition;

  /// 0 while no star was picked.
  final int stars;
  final Set<String> tags;
  final String review;

  const RatingDraft({
    this.checkedItems = const {},
    this.receivedCondition,
    this.stars = 0,
    this.tags = const {},
    this.review = '',
  });

  bool get isEmpty => checkedItems.isEmpty && stars == 0 && tags.isEmpty && review.trim().isEmpty;
}
