import 'package:flutter/material.dart';
import 'package:flutter_front_end/model/entities/registration_data.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/repositories/auth_repository.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/rules/registration_rules.dart';
import 'package:flutter_front_end/model/use_cases/connectivity_use_cases.dart';
import 'package:flutter_front_end/model/use_cases/register_student_use_case.dart';
import 'package:flutter_front_end/view/screens/register_screen.dart';
import 'package:flutter_front_end/view_model/app_view_model.dart';
import 'package:flutter_front_end/view_model/connectivity_view_model.dart';
import 'package:flutter_front_end/view_model/register_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _AlwaysOnline implements ConnectivityRepository {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watch() => const Stream.empty();
}

class _Auth implements AuthRepository {
  @override
  Future<UserEntity> register(RegistrationData data) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoApp implements AppViewModel {
  @override
  final ConnectivityViewModel connectivity = ConnectivityViewModel(
    getConnectivity: GetConnectivityUseCase(_AlwaysOnline()),
    watchConnectivity: WatchConnectivityUseCase(_AlwaysOnline()),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the sign-up name field stops at 50 characters and shows the count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: RegisterScreen(
        appState: _NoApp(),
        createViewModel: () => RegisterViewModel(registerStudent: RegisterStudentUseCase(_Auth()), onSignedIn: (_) {}),
      ),
    ));
    await tester.pump();

    final name = find.byType(TextField).first;
    expect(find.byKey(const Key('name-counter')), findsOneWidget);
    expect(find.text('0/50'), findsNWidgets(2), reason: 'name and major');

    await tester.enterText(name, 'a' * 70);
    await tester.pump();

    expect(tester.widget<TextField>(name).controller!.text, 'a' * 50);
    expect(find.text('50/50'), findsOneWidget);
    expect(RegistrationRules.validateFullName('a' * 50), isNull);
  });

  testWidgets('the major stops at 50, and name and major warn while typing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: RegisterScreen(
        appState: _NoApp(),
        createViewModel: () => RegisterViewModel(registerStudent: RegisterStudentUseCase(_Auth()), onSignedIn: (_) {}),
      ),
    ));
    await tester.pump();
    final fields = find.byType(TextField);
    final name = fields.at(0);
    final major = fields.at(3); // name, email, faculty (read only), major

    expect(find.byKey(const Key('major-hint')), findsNothing, reason: 'nothing before typing');

    await tester.enterText(major, 'b' * 70);
    await tester.pump();
    expect(tester.widget<TextField>(major).controller!.text, 'b' * 50);
    expect(find.text('50/50'), findsOneWidget);

    await tester.enterText(major, '');
    await tester.pump();
    expect(find.text('Enter your major.'), findsOneWidget, reason: 'emptied after typing');

    await tester.enterText(name, 'A');
    await tester.pump();
    expect(find.text('Your name needs at least 2 letters.'), findsOneWidget);

    await tester.enterText(name, 'Ana 😀 Gomez');
    await tester.pump();
    expect(tester.widget<TextField>(name).controller!.text, 'Ana  Gomez');
    expect(find.byKey(const Key('name-emoji-notice')), findsOneWidget);
  });
}
