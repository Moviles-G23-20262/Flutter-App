import '../entities/profile_draft.dart';
import '../entities/uniandes_program.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';
import '../repositories/draft_repositories.dart';
import '../repositories/uniandes_programs_repository.dart';

/// Saves name, major and faculty (`PATCH /users/:id`); the saved profile on the phone follows.
class UpdateProfileUseCase {
  final AuthRepository repository;
  UpdateProfileUseCase(this.repository);

  Future<UserEntity> execute({
    required String userId,
    required String fullName,
    required String major,
    String? faculty,
  }) =>
      repository.updateProfile(userId: userId, fullName: fullName, major: major, faculty: faculty);
}

/// The Uniandes undergraduate programs, for the major picker.
class GetUniandesProgramsUseCase {
  final UniandesProgramsRepository repository;
  GetUniandesProgramsUseCase(this.repository);

  Future<List<UniandesProgram>> execute() => repository.getPrograms();
}

class SearchUniandesProgramsUseCase {
  final UniandesProgramsRepository repository;
  SearchUniandesProgramsUseCase(this.repository);

  Future<List<UniandesProgram>> execute(String query) => repository.search(query);
}

class LoadProfileDraftUseCase {
  final ProfileDraftRepository repository;
  LoadProfileDraftUseCase(this.repository);

  Future<ProfileDraft?> execute(String userId) => repository.load(userId);
}

class SaveProfileDraftUseCase {
  final ProfileDraftRepository repository;
  SaveProfileDraftUseCase(this.repository);

  Future<void> execute(String userId, ProfileDraft draft) => repository.save(userId, draft);
}

class ClearProfileDraftUseCase {
  final ProfileDraftRepository repository;
  ClearProfileDraftUseCase(this.repository);

  Future<void> execute(String userId) => repository.clear(userId);
}
