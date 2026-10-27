import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_front_end/view_model/login_view_model.dart';
import 'package:flutter_front_end/model/repositories/impl/auth_repository_impl.dart';
import 'package:flutter_front_end/model/data_sources/auth_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/session_storage.dart';
import 'package:flutter_front_end/model/services/biometric_auth_service.dart';
import 'package:flutter_front_end/model/entities/registration_data.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/repositories/auth_repository.dart';
import 'package:flutter_front_end/model/repositories/biometric_authenticator.dart';
import 'package:flutter_front_end/model/use_cases/login_use_case.dart';
import 'package:flutter_front_end/model/use_cases/logout_use_case.dart';
import 'package:flutter_front_end/model/use_cases/quick_unlock_use_cases.dart';
import 'package:flutter_front_end/view/screens/login_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth/local_auth.dart';

final _user = UserEntity(
  id: 'user-1',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gomez',
  major: 'ISIS',
  rating: 0,
  createdAt: DateTime(2026, 9, 30),
);

/// The LocalAuthentication plugin, answering what the test says.
class _FakeLocalAuth implements LocalAuthentication {
  bool supported = true;
  bool canCheck = true;
  List<BiometricType> enrolled = [BiometricType.fingerprint];
  bool verifies = true;
  Object? throwOn;
  String? lastReason;
  bool? lastBiometricOnly;

  @override
  Future<bool> isDeviceSupported() async {
    if (throwOn != null) throw throwOn!;
    return supported;
  }

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => enrolled;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    lastReason = localizedReason;
    lastBiometricOnly = biometricOnly;
    if (throwOn != null) throw throwOn!;
    return verifies;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBiometrics implements BiometricAuthenticator {
  bool available = true;
  bool verifies = true;
  int prompts = 0;

  @override
  Future<bool> canCheckBiometrics() async => available;

  @override
  Future<bool> authenticate() async {
    prompts++;
    return verifies;
  }
}

/// A repository with canned answers, to test the use cases and the screen in isolation.
class _FakeAuth implements AuthRepository {
  bool enrolled = true;
  String? email = 'ana@uniandes.edu.co';
  UserEntity? restored = _user;
  Object? restoreError;
  int restores = 0;
  int forgets = 0;

  @override
  Future<bool> hasEnrolledBiometricCredential() async => enrolled;

  @override
  Future<String?> enrolledEmail() async => email;

  @override
  Future<UserEntity?> restoreWithBiometricCredential() async {
    restores++;
    if (restoreError != null) throw restoreError!;
    return restored;
  }

  @override
  Future<void> forgetBiometrics() async {
    forgets++;
    enrolled = false;
    email = null;
  }

  @override
  Future<UserEntity> login({required String email, required String password}) => throw UnimplementedError();

  @override
  Future<UserEntity> register(RegistrationData data) => throw UnimplementedError();

  @override
  Future<UserEntity?> restoreSession() => throw UnimplementedError();

  @override
  Future<UserEntity?> verifySession() async => null;

  @override
  Future<void> logout() => throw UnimplementedError();
}

class _NoApp implements AppViewModel {
  final loggedIn = <UserEntity>[];

  @override
  void login(UserEntity user) => loggedIn.add(user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessionStore implements SessionStorage {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class _BiometricStore implements BiometricCredentialStorage {
  String? token;
  String? email;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({required String token, required String email}) async {
    this.token = token;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }
}

/// The real data layer (repository, remote data source, API client) against a fake server.
class _Stack {
  bool online = true;
  String validToken = 'jwt-1';
  final requests = <String>[];
  final session = _SessionStore();
  final biometric = _BiometricStore();
  late final ApiClient api;
  late final AuthRepositoryImpl repository;

  _Stack() {
    api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (!online) throw http.ClientException('no route to host');
        final userJson = {
          'id': _user.id,
          'email': _user.email,
          'fullName': _user.fullName,
          'major': _user.major,
          'rating': 0,
          'createdAt': _user.createdAt.toIso8601String(),
        };
        if (request.url.path == '/auth/login') {
          return http.Response(jsonEncode({'user': userJson, 'accessToken': validToken}), 201);
        }
        if (request.url.path == '/auth/me') {
          final ok = request.headers['Authorization'] == 'Bearer $validToken';
          return ok ? http.Response(jsonEncode(userJson), 200) : http.Response('{"message":"Unauthorized"}', 401);
        }
        return http.Response('{}', 404);
      }),
    );
    repository = AuthRepositoryImpl(
      remote: AuthRemoteDataSourceImpl(apiClient: api),
      storage: session,
      biometricStorage: biometric,
      apiClient: api,
    );
  }
}

void main() {
  group('BiometricAuthService', () {
    late _FakeLocalAuth plugin;
    late BiometricAuthService service;

    setUp(() {
      plugin = _FakeLocalAuth();
      service = BiometricAuthService(plugin);
    });

    test('is available with supported hardware and an enrolled fingerprint', () async {
      expect(await service.canCheckBiometrics(), isTrue);
    });

    test('is not available without hardware, without a fingerprint enrolled, or when unsupported', () async {
      plugin.supported = false;
      expect(await service.canCheckBiometrics(), isFalse);

      plugin.supported = true;
      plugin.canCheck = false;
      expect(await service.canCheckBiometrics(), isFalse);

      plugin.canCheck = true;
      plugin.enrolled = [];
      expect(await service.canCheckBiometrics(), isFalse);
    });

    test('a platform error while checking means "not available"', () async {
      plugin.throwOn = PlatformException(code: 'error');
      expect(await service.canCheckBiometrics(), isFalse);

      plugin.throwOn = StateError('no plugin');
      expect(await service.canCheckBiometrics(), isFalse);
    });

    test('authenticate shows the prompt with the reason, biometrics only', () async {
      expect(await service.authenticate(), isTrue);

      expect(plugin.lastReason, 'Autentícate para ingresar a Viva Voce');
      expect(plugin.lastBiometricOnly, isTrue);
    });

    test('a rejected or cancelled prompt gives false', () async {
      plugin.verifies = false;
      expect(await service.authenticate(), isFalse);
    });

    test('PlatformException (locked out, not enrolled...) gives false, never throws', () async {
      for (final code in ['LockedOut', 'PermanentlyLockedOut', 'NotEnrolled', 'NotAvailable', 'auth_in_progress']) {
        plugin.throwOn = PlatformException(code: code, message: 'nope');
        await expectLater(service.authenticate(), completion(isFalse), reason: code);
      }
    });
  });

  group('CanQuickUnlockUseCase', () {
    test('needs an enrolled fingerprint on the phone AND an enrolled account, not an open session', () async {
      final bio = _FakeBiometrics();
      final auth = _FakeAuth();
      final useCase = CanQuickUnlockUseCase(biometrics: bio, auth: auth);

      final offer = await useCase.execute();
      expect(offer, isNotNull);
      expect(offer!.email, 'ana@uniandes.edu.co');

      auth.enrolled = false;
      expect(await useCase.execute(), isNull);

      auth.enrolled = true;
      bio.available = false;
      expect(await useCase.execute(), isNull);
    });

    test('a failing repository means no offer, not a crash', () async {
      final useCase = CanQuickUnlockUseCase(biometrics: _FakeBiometrics(), auth: _ThrowingAuth());

      expect(await useCase.execute(), isNull);
    });
  });

  group('QuickUnlockUseCase', () {
    late _FakeBiometrics bio;
    late _FakeAuth auth;
    late QuickUnlockUseCase useCase;

    setUp(() {
      bio = _FakeBiometrics();
      auth = _FakeAuth();
      useCase = QuickUnlockUseCase(biometrics: bio, auth: auth);
    });

    test('a verified fingerprint signs the enrolled account back in', () async {
      final result = await useCase.execute();

      expect(result.outcome, QuickUnlockOutcome.unlocked);
      expect(result.user, _user);
      expect(auth.restores, 1);
    });

    test('an unverified fingerprint never touches the credential', () async {
      bio.verifies = false;

      final result = await useCase.execute();

      expect(result.outcome, QuickUnlockOutcome.notVerified);
      expect(result.user, isNull);
      expect(auth.restores, 0);
    });

    test('verified, but the server rejected the credential', () async {
      auth.restored = null;

      expect((await useCase.execute()).outcome, QuickUnlockOutcome.credentialRejected);
    });

    test('offline or a server failure is reported with its message, not as a rejection', () async {
      auth.restoreError = const AuthNetworkException();
      var result = await useCase.execute();
      expect(result.outcome, QuickUnlockOutcome.unreachable);
      expect(result.message, contains("Can't reach the server"));

      auth.restoreError = const AuthServerException();
      result = await useCase.execute();
      expect(result.outcome, QuickUnlockOutcome.unreachable);
    });

    test('an unexpected failure never throws', () async {
      auth.restoreError = StateError('boom');

      final result = await useCase.execute();

      expect(result.outcome, QuickUnlockOutcome.unreachable);
      expect(result.message, isNotEmpty);
    });
  });

  test('ForgetBiometricsUseCase removes the enrolled account', () async {
    final auth = _FakeAuth();

    await ForgetBiometricsUseCase(auth).execute();

    expect(auth.forgets, 1);
    expect(auth.enrolled, isFalse);
  });

  group('Login -> Sign Out -> Quick Unlock (real data layer, fake server)', () {
    late _Stack stack;
    late _FakeBiometrics bio;

    setUp(() {
      stack = _Stack();
      bio = _FakeBiometrics();
    });

    Future<void> loginAndSignOut() async {
      await LoginUseCase(stack.repository).execute(email: 'ana@uniandes.edu.co', password: 'password1');
      await LogoutUseCase(stack.repository).execute();
    }

    test('after Sign Out the session is gone but Quick Unlock is still offered', () async {
      await loginAndSignOut();

      expect(stack.api.authToken, isNull);
      expect(stack.session.token, isNull);
      expect(stack.biometric.token, 'jwt-1');
      expect(stack.biometric.email, 'ana@uniandes.edu.co');

      final offer = await CanQuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute();
      expect(offer?.email, 'ana@uniandes.edu.co');
    });

    test('the fingerprint brings the account back without typing credentials', () async {
      await loginAndSignOut();
      stack.requests.clear();

      final result = await QuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute();

      expect(result.outcome, QuickUnlockOutcome.unlocked);
      expect(result.user?.id, 'user-1');
      expect(stack.api.authToken, 'jwt-1');
      expect(stack.session.token, 'jwt-1');
      expect(stack.requests, ['GET /auth/me'], reason: 'no login request, no credentials');
      expect(bio.prompts, 1);
    });

    test('a wrong fingerprint leaves everything signed out and the account enrolled', () async {
      await loginAndSignOut();
      bio.verifies = false;
      stack.requests.clear();

      final result = await QuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute();

      expect(result.outcome, QuickUnlockOutcome.notVerified);
      expect(stack.api.authToken, isNull);
      expect(stack.requests, isEmpty);
      expect(stack.biometric.token, 'jwt-1');
    });

    test('offline keeps the account enrolled for later', () async {
      await loginAndSignOut();
      stack.online = false;

      final result = await QuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute();

      expect(result.outcome, QuickUnlockOutcome.unreachable);
      expect(stack.biometric.token, 'jwt-1');
      expect(stack.api.authToken, isNull);

      stack.online = true;
      expect((await QuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute()).outcome,
          QuickUnlockOutcome.unlocked);
    });

    test('a token the server no longer accepts is forgotten', () async {
      await loginAndSignOut();
      stack.validToken = 'rotated';

      final result = await QuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute();

      expect(result.outcome, QuickUnlockOutcome.credentialRejected);
      expect(stack.biometric.token, isNull);
      expect(await CanQuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute(), isNull);
    });

    test('"different account" forgets the fingerprint account, and a new login enrolls the new one', () async {
      await loginAndSignOut();

      await ForgetBiometricsUseCase(stack.repository).execute();
      expect(await CanQuickUnlockUseCase(biometrics: bio, auth: stack.repository).execute(), isNull);

      stack.validToken = 'jwt-2';
      await LoginUseCase(stack.repository).execute(email: 'ana@uniandes.edu.co', password: 'password1');
      expect(stack.biometric.token, 'jwt-2');
    });

    testWidgets('on the login screen: sign out, tap Quick Unlock, land in the app', (tester) async {
      await loginAndSignOut();
      final app = _NoApp();
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: LoginScreen(
          appState: app,
          createViewModel: () => LoginViewModel(
            login: LoginUseCase(stack.repository),
            canQuickUnlock: CanQuickUnlockUseCase(biometrics: bio, auth: stack.repository),
            quickUnlock: QuickUnlockUseCase(biometrics: bio, auth: stack.repository),
            forgetBiometrics: ForgetBiometricsUseCase(stack.repository),
            onSignedIn: app.login,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('quick-unlock')), findsOneWidget);
      expect(find.text('ana@uniandes.edu.co'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quick-unlock')));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(app.loggedIn.map((u) => u.id), ['user-1']);
      expect(stack.api.authToken, 'jwt-1');
    });
  });

  group('LoginScreen Quick Unlock', () {
    late _FakeBiometrics bio;
    late _FakeAuth auth;
    late _NoApp app;

    Widget screen({bool withForget = true}) => MaterialApp(
          home: LoginScreen(
            appState: app,
            createViewModel: () => LoginViewModel(
              login: LoginUseCase(auth),
              canQuickUnlock: CanQuickUnlockUseCase(biometrics: bio, auth: auth),
              quickUnlock: QuickUnlockUseCase(biometrics: bio, auth: auth),
              forgetBiometrics: withForget ? ForgetBiometricsUseCase(auth) : null,
              onSignedIn: app.login,
            ),
          ),
        );

    Future<void> pump(WidgetTester tester) async {
      bio = _FakeBiometrics();
      auth = _FakeAuth();
      app = _NoApp();
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(screen());
      await tester.pump();
    }

    Future<void> tapQuickUnlock(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quick-unlock')));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('offers the fingerprint button and the enrolled account', (tester) async {
      await pump(tester);

      expect(find.text('Quick Unlock with Fingerprint'), findsOneWidget);
      expect(find.text('ana@uniandes.edu.co'), findsOneWidget);
      expect(find.text('Sign in with a different account'), findsOneWidget);
    });

    testWidgets('hides it without an enrolled fingerprint or without an enrolled account', (tester) async {
      bio = _FakeBiometrics()..available = false;
      auth = _FakeAuth();
      app = _NoApp();
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.byKey(const Key('quick-unlock')), findsNothing);

      bio.available = true;
      auth.enrolled = false;
      await tester.pumpWidget(KeyedSubtree(key: UniqueKey(), child: screen()));
      await tester.pump();
      expect(find.byKey(const Key('quick-unlock')), findsNothing);
    });

    testWidgets('the plain login screen has no fingerprint button', (tester) async {
      final noApp = _NoApp();
      await tester.pumpWidget(MaterialApp(home: LoginScreen(appState: noApp, createViewModel: () => LoginViewModel(login: LoginUseCase(_FakeAuth()), onSignedIn: noApp.login))));
      await tester.pump();

      expect(find.byKey(const Key('quick-unlock')), findsNothing);
    });

    testWidgets('a verified fingerprint enters the app without typing anything', (tester) async {
      await pump(tester);

      await tapQuickUnlock(tester);

      expect(bio.prompts, 1);
      expect(app.loggedIn, [_user]);
    });

    testWidgets('a failed fingerprint shows a message and keeps everything else', (tester) async {
      await pump(tester);
      bio.verifies = false;

      await tapQuickUnlock(tester);

      expect(find.textContaining('Fingerprint not verified'), findsOneWidget);
      expect(app.loggedIn, isEmpty);
      expect(auth.restores, 0);
      expect(find.byKey(const Key('quick-unlock')), findsOneWidget, reason: 'it can be tried again');
      expect(find.byKey(const Key('login-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a rejected credential hides the button and asks for the password', (tester) async {
      await pump(tester);
      auth.restored = null;

      await tapQuickUnlock(tester);

      expect(find.textContaining('no longer valid'), findsOneWidget);
      expect(find.byKey(const Key('quick-unlock')), findsNothing);
      expect(app.loggedIn, isEmpty);
    });

    testWidgets('being offline says so and keeps the button', (tester) async {
      await pump(tester);
      auth.restoreError = const AuthNetworkException();

      await tapQuickUnlock(tester);

      expect(find.textContaining("Can't reach the server"), findsOneWidget);
      expect(find.byKey(const Key('quick-unlock')), findsOneWidget);
      expect(app.loggedIn, isEmpty);
    });

    testWidgets('"Sign in with a different account" forgets the fingerprint account', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('forget-biometrics')));
      await tester.pump();
      await tester.pump();

      expect(auth.forgets, 1);
      expect(find.byKey(const Key('quick-unlock')), findsNothing);
      expect(find.byKey(const Key('forget-biometrics')), findsNothing);
      expect(find.byKey(const Key('login-button')), findsOneWidget);
    });
  });
}

class _ThrowingAuth extends _FakeAuth {
  @override
  Future<bool> hasEnrolledBiometricCredential() async => throw StateError('storage broken');
}
