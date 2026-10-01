import '../Entities/registration_data.dart';
import '../Entities/user_entity.dart';
import '../errors/auth_exceptions.dart';
import '../repositories/auth_repository.dart';
import '../rules/registration_rules.dart';

class RegisterStudentUseCase {
  final AuthRepository repository;

  RegisterStudentUseCase(this.repository);

  Future<UserEntity> execute({
    required String fullName,
    required String email,
    required String password,
    required String major,
    String? faculty,
  }) async {
    final error = RegistrationRules.validateFullName(fullName) ??
        RegistrationRules.validateEmail(email) ??
        RegistrationRules.validateMajor(major) ??
        RegistrationRules.validatePassword(password);
    if (error != null) throw InvalidRegistrationException(error);

    final cleanFaculty = faculty?.trim();

    return repository.register(
      RegistrationData(
        email: RegistrationRules.normalizeEmail(email),
        password: password,
        fullName: fullName.trim(),
        major: major.trim(),
        faculty: (cleanFaculty == null || cleanFaculty.isEmpty) ? null : cleanFaculty,
      ),
    );
  }
}
