import '../../data_sources/local/draft_photo_store.dart';
import '../../data_sources/local/draft_store.dart';
import '../../dto/draft_models.dart';
import '../../entities/listing_draft.dart';
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

/// The text and choices go to shared_preferences as one JSON; the photos are files in the
/// documents folder, named in that JSON by path.
class ListingDraftRepositoryImpl implements ListingDraftRepository {
  final DraftStore store;
  final DraftPhotoStore photos;

  ListingDraftRepositoryImpl(this.store, this.photos);

  static String _key(String userId) => 'listing_draft:$userId';

  @override
  Future<ListingDraft?> load(String userId) async {
    final json = await store.read(_key(userId));
    if (json == null) return null;
    try {
      final saved = await photos.read(userId, listingDraftPhotoPaths(json));
      return listingDraftFromJson(json, saved);
    } on Object {
      // Written by another app version in a shape this one cannot read: start over.
      return null;
    }
  }

  @override
  Future<void> save(String userId, ListingDraft draft) async {
    if (draft.isEmpty) return clear(userId);
    final paths = await photos.sync(userId, draft.photos);
    await store.write(_key(userId), listingDraftToJson(draft, paths));
  }

  @override
  Future<void> clear(String userId) async {
    await store.remove(_key(userId));
    await photos.deleteAll(userId);
  }
}
