import '../../data_sources/local/draft_store.dart';
import '../../dto/draft_models.dart';
import '../../entities/rating_draft.dart';
import '../draft_repositories.dart';

class RatingDraftRepositoryImpl implements RatingDraftRepository {
  final DraftStore store;

  RatingDraftRepositoryImpl(this.store);

  static String _key(String userId, String exchangeId) => 'rating_draft:$userId:$exchangeId';

  @override
  Future<RatingDraft?> load({required String userId, required String exchangeId}) async {
    final json = await store.read(_key(userId, exchangeId));
    if (json == null) return null;
    try {
      return ratingDraftFromJson(json);
    } on Object {
      // Written by another app version in a shape this one cannot read: start over.
      return null;
    }
  }

  @override
  Future<void> save({required String userId, required String exchangeId, required RatingDraft draft}) =>
      draft.isEmpty
          ? store.remove(_key(userId, exchangeId))
          : store.write(_key(userId, exchangeId), ratingDraftToJson(draft));

  @override
  Future<void> clear({required String userId, required String exchangeId}) =>
      store.remove(_key(userId, exchangeId));
}
