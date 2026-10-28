import 'package:flutter_front_end/model/entities/registration_data.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/repositories/auth_repository.dart';
import 'package:flutter_front_end/model/use_cases/login_use_case.dart';
import 'package:flutter_front_end/model/use_cases/register_student_use_case.dart';
import 'package:flutter_front_end/view_model/login_view_model.dart';
import 'package:flutter_front_end/view_model/register_view_model.dart';
import 'package:flutter_front_end/model/data_sources/local/draft_store.dart';
import 'package:flutter_front_end/model/repositories/impl/draft_repositories_impl.dart';
import 'package:flutter_front_end/model/use_cases/registration_draft_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _ana = UserEntity(
  id: 'user-1',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gomez',
  major: 'ISIS',
  rating: 0,
  createdAt: DateTime(2026, 9, 30),
);

class _FakeAuth implements AuthRepository {
  Exception? loginError;
  Exception? registerError;
  RegistrationData? registered;

  @override
  Future<UserEntity> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
    return _ana;
  }

  @override
  Future<UserEntity> register(RegistrationData data) async {
    if (registerError != null) throw registerError!;
    registered = data;
    return _ana;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('LoginViewModel', () {
    late _FakeAuth auth;
    late List<UserEntity> signedIn;
    late LoginViewModel vm;

    setUp(() {
      auth = _FakeAuth();
      signedIn = [];
      vm = LoginViewModel(login: LoginUseCase(auth), onSignedIn: signedIn.add);
    });

    test('an empty form only shows its problems after trying to submit', () async {
      expect(vm.emailError, isNull);
      expect(vm.passwordError, isNull);

      await vm.submit();

      expect(vm.emailError, isNotNull);
      expect(vm.passwordError, isNotNull);
      expect(signedIn, isEmpty);
    });

    test('valid credentials sign the user in and keep the loading state', () async {
      vm.setEmail('ana@uniandes.edu.co');
      vm.setPassword('correct-horse-1');

      await vm.submit();

      expect(signedIn.single.id, 'user-1');
      expect(vm.isLoading, isTrue, reason: 'the app moves to Home; the button stays busy until then');
    });

    test('wrong credentials show the message and allow another try', () async {
      auth.loginError = const InvalidCredentialsException();
      vm.setEmail('ana@uniandes.edu.co');
      vm.setPassword('wrong-password-1');

      await vm.submit();

      expect(vm.errorMessage, 'Incorrect email or password.');
      expect(vm.isLoading, isFalse);
      vm.setPassword('wrong-password-2');
      expect(vm.errorMessage, isEmpty, reason: 'typing again clears the error');
    });

    test('toggles the password visibility', () {
      expect(vm.obscurePassword, isTrue);
      vm.togglePasswordVisibility();
      expect(vm.obscurePassword, isFalse);
    });

    test('without fingerprint support there is no Quick Unlock offer', () async {
      await vm.init();
      expect(vm.canOfferQuickUnlock, isFalse);
    });
  });

  group('RegisterViewModel', () {
    late _FakeAuth auth;
    late List<UserEntity> signedIn;
    late RegisterViewModel vm;

    void fillValidForm() {
      vm.update(RegisterField.name, 'Ana Gomez');
      vm.update(RegisterField.email, 'ana@uniandes.edu.co');
      vm.update(RegisterField.major, 'Systems Engineering');
      vm.update(RegisterField.password, 'correct-horse-1');
      vm.update(RegisterField.confirm, 'correct-horse-1');
    }

    setUp(() {
      auth = _FakeAuth();
      signedIn = [];
      vm = RegisterViewModel(registerStudent: RegisterStudentUseCase(auth), onSignedIn: signedIn.add);
    });

    test('submitting an empty form marks every required field', () async {
      await vm.submit();

      for (final field in RegisterField.values) {
        if (field == RegisterField.confirm) continue;
        expect(vm.errorFor(field), isNotNull, reason: field.name);
      }
      expect(signedIn, isEmpty);
    });

    test('editing a field clears its error', () async {
      await vm.submit();
      vm.update(RegisterField.name, 'A');
      expect(vm.errorFor(RegisterField.name), isNull);
      expect(vm.errorFor(RegisterField.email), isNotNull);
    });

    test('a valid form creates the account with the faculty and signs in', () async {
      fillValidForm();
      vm.setFaculty('Faculty of Engineering');

      await vm.submit();

      expect(signedIn.single.id, 'user-1');
      expect(auth.registered?.faculty, 'Faculty of Engineering');
      expect(vm.isLoading, isFalse);
    });

    test('an email already in use is shown on the email field', () async {
      auth.registerError = const EmailAlreadyRegisteredException();
      fillValidForm();

      await vm.submit();

      expect(vm.errorFor(RegisterField.email), 'An account with this email already exists.');
      expect(vm.bannerError, isEmpty);
      expect(signedIn, isEmpty);
    });

    test('other failures show in the banner', () async {
      auth.registerError = Exception('boom');
      fillValidForm();

      await vm.submit();

      expect(vm.bannerError, 'Unexpected error. Please try again.');
    });
  });
  group('RegisterViewModel draft', () {
    late RegistrationDraftRepositoryImpl drafts;

    RegisterViewModel newViewModel(_FakeAuth auth, List<UserEntity> signedIn) => RegisterViewModel(
          registerStudent: RegisterStudentUseCase(auth),
          onSignedIn: signedIn.add,
          loadDraft: LoadRegistrationDraftUseCase(drafts),
          saveDraft: SaveRegistrationDraftUseCase(drafts),
          clearDraft: ClearRegistrationDraftUseCase(drafts),
        );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      drafts = RegistrationDraftRepositoryImpl(DraftStore());
    });

    test('name, email, major and faculty come back after the screen is closed; passwords never', () async {
      final first = newViewModel(_FakeAuth(), [])
        ..update(RegisterField.name, 'Ana Gomez')
        ..update(RegisterField.email, 'ana@uniandes.edu.co')
        ..update(RegisterField.major, 'ISIS')
        ..update(RegisterField.password, 'secret-123')
        ..setFaculty('Faculty of Engineering');
      first.dispose(); // leaving before the 0.4 s still saves

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final reopened = newViewModel(_FakeAuth(), []);
      expect(await reopened.init(), isTrue);
      expect(reopened.valueOf(RegisterField.name), 'Ana Gomez');
      expect(reopened.valueOf(RegisterField.email), 'ana@uniandes.edu.co');
      expect(reopened.valueOf(RegisterField.major), 'ISIS');
      expect(reopened.faculty, 'Faculty of Engineering');
      expect(reopened.valueOf(RegisterField.password), isEmpty);
    });

    test('creating the account deletes the draft', () async {
      final signedIn = <UserEntity>[];
      final vm = newViewModel(_FakeAuth(), signedIn)
        ..update(RegisterField.name, 'Ana Gomez')
        ..update(RegisterField.email, 'ana@uniandes.edu.co')
        ..update(RegisterField.major, 'Systems Engineering')
        ..update(RegisterField.password, 'correct-horse-1')
        ..update(RegisterField.confirm, 'correct-horse-1');
      await Future<void>.delayed(RegisterViewModel.draftDelay + const Duration(milliseconds: 100));

      await vm.submit();

      expect(signedIn, hasLength(1));
      expect(await newViewModel(_FakeAuth(), []).init(), isFalse);
    });
  });
}
