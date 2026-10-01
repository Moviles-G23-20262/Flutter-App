import 'package:flutter_front_end/Domain/Entities/registration_data.dart';
import 'package:flutter_front_end/Domain/Entities/user_entity.dart';
import 'package:flutter_front_end/Domain/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/auth_repository.dart';
import 'package:flutter_front_end/Domain/rules/registration_rules.dart';
import 'package:flutter_front_end/Domain/use_cases/register_student_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  RegistrationData? received;

  @override
  Future<UserEntity> register(RegistrationData data) async {
    received = data;
    return UserEntity(
      id: 'user-1',
      email: data.email,
      fullName: data.fullName,
      major: data.major,
      faculty: data.faculty,
      rating: 0,
      createdAt: DateTime(2026, 9, 30),
    );
  }

  @override
  Future<bool> isEmailAvailable(String email) async => true;
}

void main() {
  group('RegistrationRules', () {
    test('accepts only institutional emails, ignoring case and spaces', () {
      expect(RegistrationRules.validateEmail('ana@uniandes.edu.co'), isNull);
      expect(RegistrationRules.validateEmail('  ANA@Uniandes.edu.co '), isNull);
      expect(RegistrationRules.validateEmail('ana@gmail.com'), isNotNull);
      expect(RegistrationRules.validateEmail('ana@uniandes.edu.co.evil.com'), isNotNull);
      expect(RegistrationRules.validateEmail(''), isNotNull);
    });

    test('password must have 8 to 72 characters', () {
      expect(RegistrationRules.validatePassword('short'), isNotNull);
      expect(RegistrationRules.validatePassword('long-enough'), isNull);
      expect(RegistrationRules.validatePassword('a' * 73), isNotNull);
    });

    test('confirmation must match', () {
      expect(RegistrationRules.validateConfirmation('abc12345', 'abc12345'), isNull);
      expect(RegistrationRules.validateConfirmation('abc12345', 'other'), isNotNull);
      expect(RegistrationRules.validateConfirmation('abc12345', ''), isNotNull);
    });
  });

  group('RegisterStudentUseCase', () {
    late _FakeAuthRepository repository;
    late RegisterStudentUseCase useCase;

    setUp(() {
      repository = _FakeAuthRepository();
      useCase = RegisterStudentUseCase(repository);
    });

    test('normalizes the input before calling the repository', () async {
      final user = await useCase.execute(
        fullName: '  Ana Gomez ',
        email: ' ANA@uniandes.edu.co ',
        password: 'secret-pass',
        major: ' Systems Engineering ',
        faculty: '   ',
      );

      expect(repository.received?.email, 'ana@uniandes.edu.co');
      expect(repository.received?.fullName, 'Ana Gomez');
      expect(repository.received?.major, 'Systems Engineering');
      expect(repository.received?.faculty, isNull);
      expect(user.id, 'user-1');
    });

    test('rejects a non-institutional email without calling the repository', () async {
      await expectLater(
        useCase.execute(
          fullName: 'Ana',
          email: 'ana@gmail.com',
          password: 'secret-pass',
          major: 'ISIS',
        ),
        throwsA(isA<InvalidRegistrationException>()),
      );
      expect(repository.received, isNull);
    });

    test('rejects a weak password', () async {
      await expectLater(
        useCase.execute(
          fullName: 'Ana',
          email: 'ana@uniandes.edu.co',
          password: '123',
          major: 'ISIS',
        ),
        throwsA(isA<InvalidRegistrationException>()),
      );
    });
  });
}
