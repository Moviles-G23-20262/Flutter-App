import '../entities/rating_draft.dart';

/// The unfinished rating of one exchange, per signed-in user.
abstract class RatingDraftRepository {
  Future<RatingDraft?> load({required String userId, required String exchangeId});
  Future<void> save({required String userId, required String exchangeId, required RatingDraft draft});
  Future<void> clear({required String userId, required String exchangeId});
}
