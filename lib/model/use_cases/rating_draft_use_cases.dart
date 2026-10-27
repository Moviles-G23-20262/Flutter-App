import '../entities/rating_draft.dart';
import '../repositories/draft_repositories.dart';

class LoadRatingDraftUseCase {
  final RatingDraftRepository repository;
  LoadRatingDraftUseCase(this.repository);

  Future<RatingDraft?> execute({required String userId, required String exchangeId}) =>
      repository.load(userId: userId, exchangeId: exchangeId);
}

/// An empty draft deletes the saved one.
class SaveRatingDraftUseCase {
  final RatingDraftRepository repository;
  SaveRatingDraftUseCase(this.repository);

  Future<void> execute({required String userId, required String exchangeId, required RatingDraft draft}) =>
      repository.save(userId: userId, exchangeId: exchangeId, draft: draft);
}

class ClearRatingDraftUseCase {
  final RatingDraftRepository repository;
  ClearRatingDraftUseCase(this.repository);

  Future<void> execute({required String userId, required String exchangeId}) =>
      repository.clear(userId: userId, exchangeId: exchangeId);
}
