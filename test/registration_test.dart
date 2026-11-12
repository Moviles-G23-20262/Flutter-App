import 'package:flutter_front_end/model/entities/registration_data.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/repositories/auth_repository.dart';
import 'package:flutter_front_end/model/rules/api_validation_messages.dart';
import 'package:flutter_front_end/model/rules/registration_rules.dart';
import 'package:flutter_front_end/model/use_cases/register_student_use_case.dart';
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
  Future<UserEntity> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<UserEntity?> restoreSession() async => null;

  @override
  Future<UserEntity?> verifySession() async => null;

  @override
  Future<bool> hasEnrolledBiometricCredential() async => false;

  @override
  Future<String?> enrolledEmail() async => null;

  @override
  Future<UserEntity?> restoreWithBiometricCredential() async => null;

  @override
  Future<void> forgetBiometrics() async {}

  @override
  Future<void> logout() async {}
}

void main() {
  group('RegistrationRules', () {
    group('email', () {
      test('accepts only institutional emails, ignoring case and surrounding spaces', () {
        expect(RegistrationRules.validateEmail('ana@uniandes.edu.co'), isNull);
        expect(RegistrationRules.validateEmail('  ANA@Uniandes.edu.co '), isNull);
        expect(RegistrationRules.validateEmail('ana.gomez+x@uniandes.edu.co'), isNull);
        expect(RegistrationRules.validateEmail('ana@gmail.com'), isNotNull);
        expect(RegistrationRules.validateEmail('ana@uniandes.edu.co.evil.com'), isNotNull);
        expect(RegistrationRules.validateEmail(''), isNotNull);
      });

      test('inner spaces, emojis, odd dots, symbols and excess length are refused', () {
        expect(RegistrationRules.validateEmail('an a@uniandes.edu.co'), "The email can't contain spaces.");
        expect(RegistrationRules.validateEmail('ana @uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('ana😀@uniandes.edu.co'), "The email can't contain emojis.");
        expect(RegistrationRules.validateEmail('😀@uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('.ana@uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('ana..g@uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('ana.@uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('ana<>@uniandes.edu.co'), isNotNull);
        expect(RegistrationRules.validateEmail('${'a' * 65}@uniandes.edu.co'), 'The email is too long.');
        expect(RegistrationRules.validateEmail('${'a' * 250}@uniandes.edu.co'), 'The email is too long.');
      });
    });

    group('full name', () {
      test('accepts letters with accents, single spaces, periods and hyphens', () {
        expect(RegistrationRules.validateFullName('Ana Gómez'), isNull);
        expect(RegistrationRules.validateFullName('  Nuño   Peña-Ruiz Jr. '), isNull);
        expect(RegistrationRules.validateFullName('Li'), isNull);
      });

      test('is normalized: trimmed, inner whitespace collapsed', () {
        expect(RegistrationRules.normalizeName('  Ana \t  María\n Gómez '), 'Ana María Gómez');
      });

      test('refuses empty, emojis, digits, symbols and control characters', () {
        expect(RegistrationRules.validateFullName('   '), 'Enter your full name.');
        expect(RegistrationRules.validateFullName('Ana 😀'), "Your name can't contain emojis.");
        expect(RegistrationRules.validateFullName('😀😀'), isNotNull);
        expect(RegistrationRules.validateFullName('1234'), isNotNull);
        expect(RegistrationRules.validateFullName('..'), isNotNull);
        expect(RegistrationRules.validateFullName('Ana <b>'), isNotNull);
        expect(RegistrationRules.validateFullName(r'Ana #$%'), isNotNull);
        expect(RegistrationRules.validateFullName('Ana{Gomez}'), isNotNull);
        expect(RegistrationRules.validateFullName('Ana\x07Gomez'), isNotNull);
        expect(RegistrationRules.validateFullName('Ana\u{200B}Gomez'), isNotNull);
      });

      test('needs 2 real letters and at most 80 characters', () {
        expect(RegistrationRules.validateFullName('A'), isNotNull);
        expect(RegistrationRules.validateFullName('A.'), isNotNull);
        expect(RegistrationRules.validateFullName('a' * 80), isNull);
        expect(RegistrationRules.validateFullName('a' * 81), isNotNull);
      });
    });

    group('major', () {
      test('accepts normal majors, digits and symbols included', () {
        expect(RegistrationRules.validateMajor('Systems Engineering'), isNull);
        expect(RegistrationRules.validateMajor('Ingeniería de Sistemas (ISIS)'), isNull);
        expect(RegistrationRules.validateMajor('IIND 2'), isNull);
      });

      test('refuses empty, emojis, no letters, control characters and too long', () {
        expect(RegistrationRules.validateMajor(' '), 'Enter your major.');
        expect(RegistrationRules.validateMajor('ISIS 🎓'), "Your major can't contain emojis.");
        expect(RegistrationRules.validateMajor('1234'), isNotNull);
        expect(RegistrationRules.validateMajor('A'), isNotNull);
        expect(RegistrationRules.validateMajor('IS\x00IS'), isNotNull);
        expect(RegistrationRules.validateMajor('a' * 81), isNotNull);
      });

      test('is normalized like the name', () {
        expect(RegistrationRules.normalizeText('  Systems   Engineering '), 'Systems Engineering');
      });
    });

    group('password', () {
      test('a strong ASCII password is accepted', () {
        expect(RegistrationRules.validatePassword('CampusSwap1!'), isNull);
        expect(RegistrationRules.validatePassword('Aa1!aaaa'), isNull);
        expect(RegistrationRules.validatePassword('Aa1!${'a' * 68}'), isNull, reason: '72 characters');
      });

      test('only spaces, or any space at all, is refused', () {
        expect(RegistrationRules.validatePassword('        '), "The password can't contain spaces.");
        expect(RegistrationRules.validatePassword('Campus Swap1!'), "The password can't contain spaces.");
        expect(RegistrationRules.validatePassword(' CampusSwap1!'), isNotNull);
        expect(RegistrationRules.validatePassword('CampusSwap1! '), isNotNull);
        expect(RegistrationRules.validatePassword('Campus\tSwap1!'), isNotNull);
      });

      test('emojis and non-ASCII or invisible characters are refused', () {
        expect(RegistrationRules.validatePassword('CampusSwap1!😀'), "The password can't contain emojis.");
        expect(RegistrationRules.validatePassword('Campusñwap1!'), isNotNull);
        expect(RegistrationRules.validatePassword('CampusSwap1!\u{200B}'), isNotNull);
      });

      test('length goes from 8 to 72', () {
        expect(RegistrationRules.validatePassword('Aa1!aaa'), 'Use at least 8 characters.');
        expect(RegistrationRules.validatePassword('Aa1!${'a' * 69}'), 'Use at most 72 characters.');
        expect(RegistrationRules.validatePassword('a' * 73), 'Use at most 72 characters.');
      });

      test('needs an uppercase letter, a lowercase letter, a number and a symbol', () {
        expect(RegistrationRules.validatePassword('campusswap1!'), 'Add an uppercase letter.');
        expect(RegistrationRules.validatePassword('CAMPUSSWAP1!'), 'Add a lowercase letter.');
        expect(RegistrationRules.validatePassword('CampusSwap!!'), 'Add a number.');
        expect(RegistrationRules.validatePassword('CampusSwap11'), 'Add a symbol.');
        expect(
          RegistrationRules.validatePassword('campusswap'),
          'Add an uppercase letter, a number and a symbol.',
        );
        expect(RegistrationRules.validatePassword('long-enough'), isNotNull);
      });

      test('every printable ASCII symbol counts as a symbol', () {
        for (final symbol in r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~'''.split('')) {
          expect(RegistrationRules.validatePassword('CampusSwap1$symbol'), isNull, reason: symbol);
        }
      });

      test('cannot be the email or the name', () {
        expect(
          RegistrationRules.validatePassword('Ana@Uniandes.edu.co', email: ' ana@uniandes.edu.co '),
          "The password can't be the same as your email.",
        );
        expect(
          RegistrationRules.validatePassword('Anagomez1!', fullName: 'Anagomez1!'),
          "The password can't be the same as your name.",
        );
        expect(
          RegistrationRules.validatePassword('CampusSwap1!', email: 'ana@uniandes.edu.co', fullName: 'Ana'),
          isNull,
        );
      });
    });

    test('confirmation must match exactly', () {
      expect(RegistrationRules.validateConfirmation('CampusSwap1!', 'CampusSwap1!'), isNull);
      expect(RegistrationRules.validateConfirmation('CampusSwap1!', 'campusswap1!'), isNotNull);
      expect(RegistrationRules.validateConfirmation('CampusSwap1!', ''), isNotNull);
    });
  });

  group('ApiValidationMessages', () {
    test('turns class-validator lines into readable text', () {
      expect(
        ApiValidationMessages.friendly('email must be an email', registration: true),
        'Use your institutional email (name@uniandes.edu.co).',
      );
      expect(
        ApiValidationMessages.friendly('email must be an email'),
        'Enter a valid email, like name@domain.com.',
      );
      expect(
        ApiValidationMessages.friendly(
          'password must be longer than or equal to 8 characters\npassword must be a string',
        ),
        'Your password is too short (at least 8 characters).\nCheck your password.',
      );
      expect(
        ApiValidationMessages.friendly('password must be shorter than or equal to 72 characters'),
        'Your password is too long (at most 72 characters).',
      );
    });

    test('never shows raw or unknown validator text', () {
      expect(ApiValidationMessages.friendly('Bad Request'), ApiValidationMessages.generic);
      expect(ApiValidationMessages.friendly('foo must be bar'), ApiValidationMessages.generic);
      expect(ApiValidationMessages.friendly(''), ApiValidationMessages.generic);
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
        fullName: '  Ana   Gomez ',
        email: ' ANA@uniandes.edu.co ',
        password: 'CampusSwap1!',
        major: ' Systems   Engineering ',
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
          password: 'CampusSwap1!',
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

    test('rejects passwords without complexity, with spaces or emojis, or equal to the email', () async {
      for (final password in ['campusswap1!', 'Campus Swap1!', 'CampusSwap1!😀', 'ANA@UNIANDES.EDU.CO', '        ']) {
        await expectLater(
          useCase.execute(fullName: 'Ana Gomez', email: 'ana@uniandes.edu.co', password: password, major: 'ISIS'),
          throwsA(isA<InvalidRegistrationException>()),
          reason: password,
        );
      }
      expect(repository.received, isNull);
    });

    test('rejects a name or major with emojis or only digits', () async {
      await expectLater(
        useCase.execute(fullName: 'Ana 😀', email: 'ana@uniandes.edu.co', password: 'CampusSwap1!', major: 'ISIS'),
        throwsA(isA<InvalidRegistrationException>()),
      );
      await expectLater(
        useCase.execute(fullName: '1234', email: 'ana@uniandes.edu.co', password: 'CampusSwap1!', major: 'ISIS'),
        throwsA(isA<InvalidRegistrationException>()),
      );
      await expectLater(
        useCase.execute(fullName: 'Ana Gomez', email: 'ana@uniandes.edu.co', password: 'CampusSwap1!', major: '1234'),
        throwsA(isA<InvalidRegistrationException>()),
      );
      expect(repository.received, isNull);
    });
  });
}
