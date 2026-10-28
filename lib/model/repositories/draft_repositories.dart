import '../entities/listing_draft.dart';
import '../entities/rating_draft.dart';

/// The unfinished rating of one exchange, per signed-in user.
abstract class RatingDraftRepository {
  Future<RatingDraft?> load({required String userId, required String exchangeId});
  Future<void> save({required String userId, required String exchangeId, required RatingDraft draft});
  Future<void> clear({required String userId, required String exchangeId});
}

/// The unfinished "sell an item" form, per signed-in user.
abstract class ListingDraftRepository {
  Future<ListingDraft?> load(String userId);

  /// An empty draft deletes the saved one.
  Future<void> save(String userId, ListingDraft draft);

  /// Deletes the draft and the photos saved with it.
  Future<void> clear(String userId);
}
