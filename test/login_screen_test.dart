import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/Domain/Entities/registration_data.dart';
import 'package:flutter_front_end/Domain/Entities/user_entity.dart';
import 'package:flutter_front_end/Domain/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/Domain/repositories/auth_repository.dart';
import 'package:flutter_front_end/Domain/use_cases/login_use_case.dart';
import 'package:flutter_front_end/Presentation/Screens/login_screen.dart';
import 'package:flutter_front_end/Presentation/State%20Management/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _user = UserEntity(
  id: 'user-1',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gomez',
  major: 'ISIS',
  rating: 0,
  createdAt: DateTime(2026, 9, 30),
);

class _FakeAuth implements AuthRepository {
  final logins = <({String email, String password})>[];
  Object? error;
  Completer<void>? hang;

  @override
  Future<UserEntity> login({required String email, required String password}) async {
    logins.add((email: email, password: password));
    if (hang != null) await hang!.future;
    if (error != null) throw error!;
    return _user;
  }

  @override
  Future<UserEntity> register(RegistrationData data) => throw UnimplementedError();

  @override
  Future<UserEntity?> restoreSession() => throw UnimplementedError();

  @override
  Future<bool> hasEnrolledBiometricCredential() async => false;

  @override
  Future<String?> enrolledEmail() async => null;

  @override
  Future<UserEntity?> restoreWithBiometricCredential() async => null;

  @override
  Future<void> forgetBiometrics() async {}

  @override
  Future<void> logout() => throw UnimplementedError();
}

class _NoApp implements AppState {
  final loggedIn = <UserEntity>[];

  @override
  void login(UserEntity user) => loggedIn.add(user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuth auth;
  late _NoApp app;

  Future<void> pump(WidgetTester tester) async {
    auth = _FakeAuth();
    app = _NoApp();
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(appState: app, login: LoginUseCase(auth))));
  }

  TextField field(WidgetTester tester, String key) => tester.widget<TextField>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
      );

  Future<void> type(WidgetTester tester, {String? email, String? password}) async {
    if (email != null) await tester.enterText(find.byKey(const Key('login-email')), email);
    if (password != null) await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pump();
    await tester.pump();
  }

  group('input rules', () {
    testWidgets('the email field uses the email keyboard and the password field hides its text', (tester) async {
      await pump(tester);

      expect(field(tester, 'login-email').keyboardType, TextInputType.emailAddress);
      expect(field(tester, 'login-password').obscureText, isTrue);
    });

    testWidgets('emojis cannot be typed in the email or the password', (tester) async {
      await pump(tester);

      await type(tester, email: 'ana😀@uni🎉andes.edu.co', password: 'pass😀word👍1');

      expect(field(tester, 'login-email').controller!.text, 'ana@uniandes.edu.co');
      expect(field(tester, 'login-password').controller!.text, 'passwordx'.replaceAll('x', '1'));
    });

    testWidgets('spaces around (or inside) the email are removed as it is typed', (tester) async {
      await pump(tester);

      await type(tester, email: '  ana @uniandes.edu.co  ');

      expect(field(tester, 'login-email').controller!.text, 'ana@uniandes.edu.co');
    });

    testWidgets('a badly formed email shows an error right away', (tester) async {
      await pump(tester);

      await type(tester, email: 'ana@uniandes');

      expect(find.text('Enter a valid email, like name@domain.com.'), findsOneWidget);

      await type(tester, email: 'ana@uniandes.edu.co');
      expect(find.text('Enter a valid email, like name@domain.com.'), findsNothing);
    });

    testWidgets('an empty form is not sent and says what is missing', (tester) async {
      await pump(tester);

      await submit(tester);

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(auth.logins, isEmpty);
    });

    testWidgets('a password of only spaces is flagged at once and never sent', (tester) async {
      await pump(tester);
      await type(tester, email: 'ana@uniandes.edu.co', password: '          ');

      expect(find.text("The password can't be only spaces."), findsOneWidget);

      await submit(tester);
      expect(auth.logins, isEmpty);
    });

    testWidgets('a short password is reported on submit, not while typing', (tester) async {
      await pump(tester);
      await type(tester, email: 'ana@uniandes.edu.co', password: 'abc');
      expect(find.text('Use at least 8 characters.'), findsNothing);

      await submit(tester);

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(auth.logins, isEmpty);
    });

    testWidgets('the eye button shows and hides the password', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('toggle-password')));
      await tester.pump();
      expect(field(tester, 'login-password').obscureText, isFalse);

      await tester.tap(find.byKey(const Key('toggle-password')));
      await tester.pump();
      expect(field(tester, 'login-password').obscureText, isTrue);
    });
  });

  group('sending the credentials', () {
    testWidgets('a valid form logs in with the cleaned email and enters the app', (tester) async {
      await pump(tester);
      await type(tester, email: 'Ana@Uniandes.EDU.co', password: 'secret-pass');

      await submit(tester);

      expect(auth.logins.single.email, 'ana@uniandes.edu.co');
      expect(auth.logins.single.password, 'secret-pass');
      expect(app.loggedIn, [_user]);
    });

    testWidgets('a 401 shows a clear message, no crash, and the form works again', (tester) async {
      await pump(tester);
      auth.error = const InvalidCredentialsException();
      await type(tester, email: 'ana@uniandes.edu.co', password: 'wrong-pass');

      await submit(tester);

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(app.loggedIn, isEmpty);
      expect(field(tester, 'login-email').enabled, isTrue);
      expect(find.text('Log In'), findsOneWidget);

      auth.error = null;
      await type(tester, password: 'right-pass');
      await submit(tester);
      expect(app.loggedIn, [_user]);
    });

    testWidgets('no connection, a server failure and a surprise each get a message', (tester) async {
      await pump(tester);
      await type(tester, email: 'ana@uniandes.edu.co', password: 'secret-pass');

      const cases = {
        'network': (AuthNetworkException(), "Can't reach the server. Check your connection and try again."),
        'server': (AuthServerException(), 'Something went wrong on our side. Please try again later.'),
      };
      for (final entry in cases.entries) {
        auth.error = entry.value.$1;
        await submit(tester);
        expect(find.text(entry.value.$2), findsOneWidget, reason: entry.key);
      }

      auth.error = StateError('boom');
      await submit(tester);
      expect(find.text('Unexpected error. Please try again.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('double tap sends one request and the button is disabled meanwhile', (tester) async {
      await pump(tester);
      auth.hang = Completer<void>();
      await type(tester, email: 'ana@uniandes.edu.co', password: 'secret-pass');

      await tester.tap(find.byKey(const Key('login-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-button')), warnIfMissed: false);
      await tester.pump();

      expect(auth.logins, hasLength(1));
      expect(find.text('Logging in…'), findsNothing, reason: 'the spinner replaces the label');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(field(tester, 'login-email').enabled, isFalse);

      auth.hang!.complete();
      await tester.pump();
      await tester.pump();
      expect(app.loggedIn, [_user]);
    });

    testWidgets('pressing Done on the keyboard submits the form', (tester) async {
      await pump(tester);
      await type(tester, email: 'ana@uniandes.edu.co', password: 'secret-pass');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      expect(auth.logins, hasLength(1));
    });
  });
}
