import '../entities/registration_data.dart';
import '../entities/user_entity.dart';
import '../exceptions/auth_exceptions.dart';
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
        RegistrationRules.validatePassword(password, email: email, fullName: fullName);
    if (error != null) throw InvalidRegistrationException(error);

    final cleanFaculty = faculty?.trim();

    return repository.register(
      RegistrationData(
        email: RegistrationRules.normalizeEmail(email),
        password: password,
        fullName: RegistrationRules.normalizeName(fullName),
        major: RegistrationRules.normalizeText(major),
        faculty: (cleanFaculty == null || cleanFaculty.isEmpty) ? null : cleanFaculty,
      ),
    );
  }
}
