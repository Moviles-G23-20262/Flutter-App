import '../entities/listing_draft.dart';
import '../repositories/draft_repositories.dart';

class LoadListingDraftUseCase {
  final ListingDraftRepository repository;
  LoadListingDraftUseCase(this.repository);

  Future<ListingDraft?> execute(String userId) => repository.load(userId);
}

/// An empty draft deletes the saved one.
class SaveListingDraftUseCase {
  final ListingDraftRepository repository;
  SaveListingDraftUseCase(this.repository);

  Future<void> execute(String userId, ListingDraft draft) => repository.save(userId, draft);
}

/// Deletes the draft and its photos: the listing was published or queued, or it was discarded.
class ClearListingDraftUseCase {
  final ListingDraftRepository repository;
  ClearListingDraftUseCase(this.repository);

  Future<void> execute(String userId) => repository.clear(userId);
}
