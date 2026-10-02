import 'dart:convert';

import 'package:flutter_front_end/Data/Models/auth_session_model.dart';
import 'package:flutter_front_end/Data/Repositories/auth_repository_impl.dart';
import 'package:flutter_front_end/Data/data_sources/auth_remote_data_source.dart';
import 'package:flutter_front_end/Data/data_sources/session_storage.dart';
import 'package:flutter_front_end/Domain/Entities/registration_data.dart';
import 'package:flutter_front_end/Domain/Entities/user_entity.dart';
import 'package:flutter_front_end/Domain/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/auth_repository.dart';
import 'package:flutter_front_end/Domain/use_cases/login_use_case.dart';
import 'package:flutter_front_end/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _user = UserEntity(
  id: 'user-1',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gomez',
  major: 'ISIS',
  rating: 0,
  createdAt: DateTime(2026, 9, 30),
);

const _registration = RegistrationData(
  email: 'a@b.co',
  password: 'secret-pass',
  fullName: 'Ana',
  major: 'ISIS',
);

class _MemoryStorage implements SessionStorage {
  String? token;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

/// Returns canned values, or throws [error] when it is set.
class _FakeRemote implements AuthRemoteDataSource {
  Object? error;

  @override
  Future<AuthSessionModel> login({required String email, required String password}) async {
    if (error != null) throw error!;
    return AuthSessionModel(user: _user, accessToken: 'jwt-token');
  }

  @override
  Future<AuthSessionModel> register(RegistrationData data) async {
    if (error != null) throw error!;
    return AuthSessionModel(user: _user, accessToken: 'jwt-token');
  }

  @override
  Future<UserEntity> me() async {
    if (error != null) throw error!;
    return _user;
  }
}

class _RecordingRepository implements AuthRepository {
  ({String email, String password})? received;

  @override
  Future<UserEntity> login({required String email, required String password}) async {
    received = (email: email, password: password);
    return _user;
  }

  @override
  Future<UserEntity> register(RegistrationData data) => throw UnimplementedError();

  @override
  Future<UserEntity?> restoreSession() => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();
}

void main() {
  group('LoginUseCase', () {
    test('normalizes the email and accepts non-institutional domains', () async {
      final repository = _RecordingRepository();

      await LoginUseCase(repository).execute(email: '  Maria@University.EDU ', password: 'pw');

      expect(repository.received?.email, 'maria@university.edu');
    });

    test('rejects empty fields without calling the repository', () async {
      final repository = _RecordingRepository();

      await expectLater(
        LoginUseCase(repository).execute(email: '', password: 'pw'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(repository.received, isNull);
    });
  });

  group('AuthRepositoryImpl', () {
    late _FakeRemote remote;
    late _MemoryStorage storage;
    late ApiClient apiClient;
    late AuthRepositoryImpl repository;

    setUp(() {
      remote = _FakeRemote();
      storage = _MemoryStorage();
      apiClient = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response('', 200)),
      );
      repository = AuthRepositoryImpl(remote: remote, storage: storage, apiClient: apiClient);
    });

    test('login stores the token and arms the api client', () async {
      final user = await repository.login(email: 'a@b.co', password: 'pw');

      expect(user.id, 'user-1');
      expect(storage.token, 'jwt-token');
      expect(apiClient.authToken, 'jwt-token');
    });

    test('register signs the user in too', () async {
      await repository.register(_registration);

      expect(storage.token, 'jwt-token');
      expect(apiClient.authToken, 'jwt-token');
    });

    test('maps backend statuses to auth exceptions', () async {
      remote.error = const ApiException(401, 'Invalid credentials');
      await expectLater(
        repository.login(email: 'a@b.co', password: 'pw'),
        throwsA(isA<InvalidCredentialsException>()),
      );

      remote.error = const ApiException(409, 'A user with this email already exists');
      await expectLater(
        repository.register(_registration),
        throwsA(isA<EmailAlreadyRegisteredException>()),
      );

      remote.error = const ApiException(500, 'boom');
      await expectLater(
        repository.login(email: 'a@b.co', password: 'pw'),
        throwsA(isA<AuthServerException>()),
      );

      remote.error = const NetworkException('offline');
      await expectLater(
        repository.login(email: 'a@b.co', password: 'pw'),
        throwsA(isA<AuthNetworkException>()),
      );
      expect(storage.token, isNull);
    });

    test('restoreSession returns null without a stored token', () async {
      expect(await repository.restoreSession(), isNull);
    });

    test('restoreSession signs back in with a valid token', () async {
      storage.token = 'jwt-token';

      final user = await repository.restoreSession();

      expect(user?.id, 'user-1');
      expect(apiClient.authToken, 'jwt-token');
    });

    test('an expired token is discarded, but being offline keeps it', () async {
      storage.token = 'old-token';
      remote.error = const NetworkException('offline');
      expect(await repository.restoreSession(), isNull);
      expect(storage.token, 'old-token');

      remote.error = const ApiException(401, 'Invalid or expired token');
      expect(await repository.restoreSession(), isNull);
      expect(storage.token, isNull);
      expect(apiClient.authToken, isNull);
    });

    test('logout clears the stored session', () async {
      await repository.login(email: 'a@b.co', password: 'pw');

      await repository.logout();

      expect(storage.token, isNull);
      expect(apiClient.authToken, isNull);
    });
  });

  group('ApiClient', () {
    test('trims the trailing slash of the base URL and sends the bearer token', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'https://api.test/',
        client: MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      )..authToken = 'jwt-token';

      await client.get('/auth/me');

      expect(seen.url.toString(), 'https://api.test/auth/me');
      expect(seen.headers['Authorization'], 'Bearer jwt-token');
    });

    test('turns error bodies into ApiException, joining validation arrays', () async {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'message': ['email must be an email', 'password too short'],
              }),
              400,
            )),
      );

      await expectLater(
        client.post('/auth/register', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'email must be an email\npassword too short')),
      );
    });

    test('reports connection failures as NetworkException', () async {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => throw http.ClientException('no route to host')),
      );

      await expectLater(client.get('/x'), throwsA(isA<NetworkException>()));
    });
  });
}
