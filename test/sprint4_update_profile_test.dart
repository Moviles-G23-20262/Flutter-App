// PATCH /users/:id from AuthRepositoryImpl: only the editable fields are sent and the profile
// saved on the phone ('device' / 'signed_in_profile') is replaced, so an offline launch shows it.
import 'dart:convert';

import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/auth_remote_data_source.dart';
import 'package:flutter_front_end/model/data_sources/local/app_database.dart';
import 'package:flutter_front_end/model/data_sources/local/response_cache.dart';
import 'package:flutter_front_end/model/data_sources/session_storage.dart';
import 'package:flutter_front_end/model/dto/auth_session_model.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/repositories/impl/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Session implements SessionStorage {
  String? token = 'jwt';

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class _NoBiometrics implements BiometricCredentialStorage {
  @override
  Future<String?> readToken() async => null;

  @override
  Future<String?> readEmail() async => null;

  @override
  Future<void> save({required String token, required String email}) async {}

  @override
  Future<void> clear() async {}
}

Map<String, dynamic> _userJson({
  String fullName = 'Ana Gómez',
  String major = 'ISIS',
  String? faculty,
  String? emailVerifiedAt = '2026-10-01T12:00:00.000Z',
}) =>
    {
      'id': 'user-1',
      'email': 'ana@uniandes.edu.co',
      'fullName': fullName,
      'major': major,
      'faculty': faculty,
      'rating': 4.5,
      'createdAt': '2026-09-30T00:00:00.000Z',
      'emailVerifiedAt': emailVerifiedAt,
    };

void main() {
  sqfliteFfiInit();

  group('UserEntity.emailVerifiedAt', () {
    test('a profile saved before the field existed still reads (null)', () {
      final json = _userJson()..remove('emailVerifiedAt');

      final user = userEntityFromJson(json);

      expect(user.emailVerifiedAt, isNull);
      expect(user.isEmailVerified, isFalse);
    });

    test('is read, written and copied', () {
      final user = userEntityFromJson(_userJson());

      expect(user.emailVerifiedAt, DateTime.utc(2026, 10, 1, 12));
      expect(userEntityFromJson(userEntityToJson(user)).emailVerifiedAt, user.emailVerifiedAt);
      expect(user.copyWith(fullName: 'Ana').emailVerifiedAt, user.emailVerifiedAt);
      expect(user.copyWith(emailVerifiedAt: null).emailVerifiedAt, isNull);
    });
  });

  group('AuthRepositoryImpl.updateProfile', () {
    late AppDatabase db;
    late ResponseCache cache;
    late List<http.Request> requests;
    late http.Response Function(http.Request request) answer;
    late bool offline;

    AuthRepositoryImpl repository() {
      final client = ApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          requests.add(request);
          if (offline) throw http.ClientException('no network');
          return answer(request);
        }),
      )..authToken = 'jwt';
      return AuthRepositoryImpl(
        remote: AuthRemoteDataSourceImpl(apiClient: client),
        storage: _Session(),
        biometricStorage: _NoBiometrics(),
        apiClient: client,
        profileCache: cache,
      );
    }

    setUp(() async {
      db = AppDatabase.withFactory(databaseFactoryFfi);
      cache = ResponseCache(db);
      requests = [];
      offline = false;
      answer = (request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_userJson(fullName: body['fullName'], major: body['major'], faculty: body['faculty'])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      };
      // The profile saved at sign-in.
      await cache.save('device', 'signed_in_profile', _userJson());
    });

    tearDown(() => db.close());

    test('sends PATCH /users/:id with only fullName, major and faculty', () async {
      await repository().updateProfile(
        userId: 'user-1',
        fullName: 'Ana María Gómez',
        major: 'Ingeniería de Sistemas y Computación',
        faculty: 'Ingeniería',
      );

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/users/user-1');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'fullName', 'major', 'faculty'});
      expect(body, {
        'fullName': 'Ana María Gómez',
        'major': 'Ingeniería de Sistemas y Computación',
        'faculty': 'Ingeniería',
      });
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('password'), isFalse);
    });

    test('returns the saved profile and overwrites signed_in_profile in ResponseCache', () async {
      final updated = await repository().updateProfile(
        userId: 'user-1',
        fullName: 'Ana María Gómez',
        major: 'Economía',
        faculty: 'Economía',
      );

      expect(updated.fullName, 'Ana María Gómez');
      expect(updated.emailVerifiedAt, isNotNull);
      // A fresh cache reads SQLite, as after closing and opening the app.
      final saved = await ResponseCache(db).read('device', 'signed_in_profile');
      final profile = userEntityFromJson(saved!.data as Map<String, dynamic>);
      expect(profile.fullName, 'Ana María Gómez');
      expect(profile.major, 'Economía');
      expect(profile.faculty, 'Economía');
    });

    test('an offline launch after the edit opens with the new profile', () async {
      await repository().updateProfile(userId: 'user-1', fullName: 'Ana Nueva', major: 'Derecho', faculty: 'Derecho');
      offline = true;
      cache = ResponseCache(db);

      final restored = await repository().restoreSession();

      expect(restored?.fullName, 'Ana Nueva');
      expect(restored?.major, 'Derecho');
    });

    test('a null faculty is sent as null, which clears it', () async {
      await repository().updateProfile(userId: 'user-1', fullName: 'Ana', major: 'Medicina');

      expect((jsonDecode(requests.single.body) as Map)['faculty'], isNull);
    });

    test('without a connection it throws NetworkException and the saved profile stays', () async {
      offline = true;

      await expectLater(
        repository().updateProfile(userId: 'user-1', fullName: 'Otra', major: 'Derecho'),
        throwsA(isA<NetworkException>()),
      );

      final saved = await ResponseCache(db).read('device', 'signed_in_profile');
      expect((saved!.data as Map)['fullName'], 'Ana Gómez');
    });

    test('a 400 becomes a ProfileUpdateException with a readable message; nothing is saved', () async {
      answer = (_) => http.Response(jsonEncode({'message': ['fullName must have at least 2 letters']}), 400);

      await expectLater(
        repository().updateProfile(userId: 'user-1', fullName: 'A.', major: 'Derecho'),
        throwsA(isA<ProfileUpdateException>()
            .having((e) => e.message, 'message', 'Check your full name: use at least 2 letters.')),
      );
      final saved = await ResponseCache(db).read('device', 'signed_in_profile');
      expect((saved!.data as Map)['fullName'], 'Ana Gómez');
    });

    test('a 403 says only the own profile can be edited', () async {
      answer = (_) => http.Response(jsonEncode({'message': 'Forbidden'}), 403);

      await expectLater(
        repository().updateProfile(userId: 'user-2', fullName: 'Ana', major: 'Derecho'),
        throwsA(isA<ProfileUpdateException>().having((e) => e.message, 'message', contains('own profile'))),
      );
    });
  });

  test('UserEntity keeps equality by id after an edit', () {
    final before = userEntityFromJson(_userJson());
    final after = before.copyWith(fullName: 'Otra');

    expect(after, before);
    expect(after, isA<UserEntity>());
  });
}
