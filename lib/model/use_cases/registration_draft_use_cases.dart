import '../entities/registration_draft.dart';
import '../repositories/draft_repositories.dart';

class LoadRegistrationDraftUseCase {
  final RegistrationDraftRepository repository;
  LoadRegistrationDraftUseCase(this.repository);

  Future<RegistrationDraft?> execute() => repository.load();
}

/// An empty draft deletes the saved one.
class SaveRegistrationDraftUseCase {
  final RegistrationDraftRepository repository;
  SaveRegistrationDraftUseCase(this.repository);

  Future<void> execute(RegistrationDraft draft) => repository.save(draft);
}

class ClearRegistrationDraftUseCase {
  final RegistrationDraftRepository repository;
  ClearRegistrationDraftUseCase(this.repository);

  Future<void> execute() => repository.clear();
}
