import '../dto/draft_models.dart';
import '../entities/rating_draft.dart';

/// The unfinished rating of one exchange, per signed-in user.
abstract class RatingDraftRepository {
  Future<RatingDraft?> load({required String userId, required String exchangeId});
  Future<void> save({required String userId, required String exchangeId, required RatingDraft draft});
  Future<void> clear({required String userId, required String exchangeId});
}

/// The unfinished student registration form. Passwords are never stored.
abstract class RegistrationDraftRepository {
  Future<RegistrationDraft?> load();
  Future<void> save(RegistrationDraft draft);
  Future<void> clear();
}

/// The unfinished listing form, per signed-in user.
abstract class SellDraftRepository {
  Future<SellDraft?> load({required String userId});
  Future<void> save({required String userId, required SellDraft draft});
  Future<void> clear({required String userId});
}
