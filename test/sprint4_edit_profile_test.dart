// Edit Profile: validations identical to the server DTO, the Uniandes major picker, the draft in
// shared_preferences and every connectivity case (offline at open, lost while editing, back while
// on the screen, lost while saving).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_front_end/app/network/api_client.dart';
import 'package:flutter_front_end/model/data_sources/local/draft_store.dart';
import 'package:flutter_front_end/model/entities/profile_draft.dart';
import 'package:flutter_front_end/model/entities/registration_data.dart';
import 'package:flutter_front_end/model/entities/uniandes_program.dart';
import 'package:flutter_front_end/model/entities/user_entity.dart';
import 'package:flutter_front_end/model/exceptions/auth_exceptions.dart';
import 'package:flutter_front_end/model/repositories/auth_repository.dart';
import 'package:flutter_front_end/model/repositories/connectivity_repository.dart';
import 'package:flutter_front_end/model/repositories/draft_repositories.dart';
import 'package:flutter_front_end/model/repositories/impl/draft_repositories_impl.dart';
import 'package:flutter_front_end/model/repositories/impl/uniandes_programs_repository_impl.dart';
import 'package:flutter_front_end/model/rules/profile_rules.dart';
import 'package:flutter_front_end/model/use_cases/profile_use_cases.dart';
import 'package:flutter_front_end/view/screens/edit_profile_screen.dart';
import 'package:flutter_front_end/view_model/edit_profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _ana = UserEntity(
  id: 'user-1',
  email: 'ana@uniandes.edu.co',
  fullName: 'Ana Gómez',
  major: 'ISIS', // legacy: not an exact catalog name
  faculty: 'Faculty of Engineering',
  rating: 4.5,
  createdAt: DateTime(2026, 9, 30),
);

final _catalog = jsonEncode({
  'programs': [
    {'name': 'Ingeniería de Sistemas y Computación', 'faculty': 'Ingeniería'},
    {'name': 'Ingeniería Electrónica', 'faculty': 'Ingeniería'},
    {'name': 'Economía', 'faculty': 'Economía'},
    {'name': 'Diseño', 'faculty': 'Arquitectura y Diseño'},
  ],
});

/// Records every PATCH; answers [next] (a user, or an exception to throw). [gate] holds it open.
class _Auth implements AuthRepository {
  final calls = <Map<String, String?>>[];
  Object? next;
  Completer<void>? gate;

  @override
  Future<UserEntity> updateProfile({
    required String userId,
    required String fullName,
    required String major,
    String? faculty,
  }) async {
    calls.add({'userId': userId, 'fullName': fullName, 'major': major, 'faculty': faculty});
    await gate?.future;
    final answer = next;
    if (answer is Exception) throw answer;
    if (answer is UserEntity) return answer;
    return _ana.copyWith(fullName: fullName, major: major, faculty: faculty);
  }

  @override
  Future<UserEntity> register(RegistrationData data) => throw UnimplementedError();

  @override
  Future<UserEntity> login({required String email, required String password}) => throw UnimplementedError();

  @override
  Future<UserEntity?> restoreSession() => throw UnimplementedError();

  @override
  Future<UserEntity?> verifySession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<bool> hasEnrolledBiometricCredential() async => false;

  @override
  Future<String?> enrolledEmail() async => null;

  @override
  Future<UserEntity?> restoreWithBiometricCredential() async => null;

  @override
  Future<void> forgetBiometrics() async {}
}

class _Network implements ConnectivityRepository {
  bool online;
  final controller = StreamController<bool>.broadcast();

  _Network({this.online = true});

  void set(bool value) {
    online = value;
    controller.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watch() => controller.stream;
}

/// A draft repository whose load waits for [gate], to see that the catalog loads at the same time.
class _GatedDrafts implements ProfileDraftRepository {
  final ProfileDraftRepository inner;
  final gate = Completer<void>();
  bool started = false;

  _GatedDrafts(this.inner);

  @override
  Future<ProfileDraft?> load(String userId) async {
    started = true;
    await gate.future;
    return inner.load(userId);
  }

  @override
  Future<void> save(String userId, ProfileDraft draft) => inner.save(userId, draft);

  @override
  Future<void> clear(String userId) => inner.clear(userId);
}

class _Harness {
  final auth = _Auth();
  final _Network network;
  final ProfileDraftRepository drafts;
  final UniandesProgramsRepositoryImpl programs;
  final saved = <UserEntity>[];

  _Harness({bool online = true, ProfileDraftRepository? drafts, Future<String> Function()? loadCatalog})
      : network = _Network(online: online),
        drafts = drafts ?? ProfileDraftRepositoryImpl(DraftStore()),
        programs = UniandesProgramsRepositoryImpl(load: loadCatalog ?? () async => _catalog);

  EditProfileViewModel viewModel({UserEntity? user}) => EditProfileViewModel(
        user: user ?? _ana,
        updateProfile: UpdateProfileUseCase(auth),
        getPrograms: GetUniandesProgramsUseCase(programs),
        searchPrograms: SearchUniandesProgramsUseCase(programs),
        loadDraft: LoadProfileDraftUseCase(drafts),
        saveDraft: SaveProfileDraftUseCase(drafts),
        clearDraft: ClearProfileDraftUseCase(drafts),
        connectivity: network,
        onSaved: saved.add,
      );

  Future<Map<String, dynamic>?> storedDraft() async {
    final text = (await SharedPreferences.getInstance()).getString(ProfileDraftRepositoryImpl.key(_ana.id));
    return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
  }
}

UniandesProgram _program(EditProfileViewModel vm, String name) => vm.programs.singleWhere((p) => p.name == name);

/// Lets stream events and fire-and-forget futures run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ProfileRules (same as UpdateUserDto)', () {
    test('fullName: spaces collapsed and trimmed before validating and sending', () {
      expect(ProfileRules.normalize('  Ana    María \t Gómez  '), 'Ana María Gómez');
      expect(ProfileRules.validateFullName('  Ana    María  '), isNull);
    });

    test('fullName: letters with accents and ñ, spaces, "." and "-" only', () {
      expect(ProfileRules.validateFullName('José Ñúñez-Peña Jr.'), isNull);
      expect(ProfileRules.validateFullName('Ana3'), isNotNull);
      expect(ProfileRules.validateFullName('Ana_Gómez'), isNotNull);
      expect(ProfileRules.validateFullName('Ana 😀'), isNotNull);
    });

    test('fullName: 2 to 50 characters and at least 2 letters', () {
      expect(ProfileRules.validateFullName(''), isNotNull);
      expect(ProfileRules.validateFullName('A'), isNotNull);
      expect(ProfileRules.validateFullName('A.-'), isNotNull);
      expect(ProfileRules.validateFullName('Al'), isNull);
      expect(ProfileRules.validateFullName('a' * 50), isNull);
      expect(ProfileRules.validateFullName('a' * 51), isNotNull);
    });

    test('major: required, at most 50, at least 2 letters, no emojis or control characters', () {
      expect(ProfileRules.validateMajor(''), isNotNull);
      expect(ProfileRules.validateMajor('A1'), isNotNull);
      expect(ProfileRules.validateMajor('Economía 📈'), isNotNull);
      expect(ProfileRules.validateMajor('Econo​mía'), isNotNull);
      expect(ProfileRules.validateMajor('a' * 51), isNotNull);
      expect(ProfileRules.validateMajor('Economía'), isNull);
    });

    test('faculty: optional, at most 80, no control characters', () {
      expect(ProfileRules.validateFaculty(''), isNull);
      expect(ProfileRules.validateFaculty('Ingeniería'), isNull);
      expect(ProfileRules.validateFaculty('a' * 80), isNull);
      expect(ProfileRules.validateFaculty('a' * 81), isNotNull);
      expect(ProfileRules.validateFaculty('Inge\u0007niería'), isNotNull);
    });
  });

  group('EditProfileViewModel', () {
    test('loads the catalog and the draft at the same time (Future.wait)', () async {
      final drafts = _GatedDrafts(ProfileDraftRepositoryImpl(DraftStore()));
      var catalogStarted = false;
      final catalogGate = Completer<void>();
      final harness = _Harness(
        drafts: drafts,
        loadCatalog: () async {
          catalogStarted = true;
          await catalogGate.future;
          return _catalog;
        },
      );
      final vm = harness.viewModel();

      final init = vm.init();
      await _settle();
      expect(catalogStarted, isTrue);
      expect(drafts.started, isTrue);
      expect(vm.isLoading, isTrue);

      catalogGate.complete();
      drafts.gate.complete();
      await init;
      expect(vm.isLoading, isFalse);
      expect(vm.programs, hasLength(4));
      vm.dispose();
    });

    test('a legacy major is kept and shown; picking a program fills in its faculty', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();

      expect(vm.major, 'ISIS');
      expect(vm.isLegacyMajor, isTrue);
      expect(vm.majorError, isNull); // the major the account already has can stay

      await vm.selectProgram(_program(vm, 'Ingeniería Electrónica'));

      expect(vm.isLegacyMajor, isFalse);
      expect(vm.major, 'Ingeniería Electrónica');
      expect(vm.faculty, 'Ingeniería');
      expect(vm.selectedProgram?.faculty, 'Ingeniería');

      await vm.setFaculty('Facultad de Ingeniería');
      expect(vm.faculty, 'Facultad de Ingeniería');
      expect(vm.facultyError, isNull);
      vm.dispose();
    });

    test('invalid fields block Save with a reason', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();

      await vm.setFullName('A');
      expect(vm.fullNameError, isNotNull);
      expect(vm.canSave, isFalse);
      expect(vm.saveDisabledReason, EditProfileViewModel.invalidReason);

      await vm.setFullName('Ana Gómez');
      expect(vm.saveDisabledReason, EditProfileViewModel.noChangesReason);

      await vm.setFaculty('x' * 81);
      expect(vm.facultyError, isNotNull);
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('every change is written to the draft in shared_preferences', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();

      await vm.setFullName('Ana  María');
      await vm.selectProgram(_program(vm, 'Economía'));

      final draft = await harness.storedDraft();
      expect(draft?['fullName'], 'Ana  María');
      expect(draft?['major'], 'Economía');
      expect(draft?['faculty'], 'Economía');
      vm.dispose();
    });

    test('a draft left by an earlier visit is restored; discarding deletes it', () async {
      final harness = _Harness();
      final first = harness.viewModel();
      await first.init();
      await first.setFullName('Ana Restaurada');
      first.dispose();

      final vm = harness.viewModel();
      await vm.init();
      expect(vm.restoredDraft, isTrue);
      expect(vm.fullName, 'Ana Restaurada');

      await vm.discardChanges();
      expect(vm.fullName, 'Ana Gómez');
      expect(vm.restoredDraft, isFalse);
      expect(await harness.storedDraft(), isNull);
      vm.dispose();
    });

    test('a successful save sends the normalized fields, clears the draft and reports the user', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();
      await vm.setFullName('  Ana    María   Gómez ');
      await vm.selectProgram(_program(vm, 'Ingeniería de Sistemas y Computación'));
      expect(await harness.storedDraft(), isNotNull);

      expect(await vm.save(), isTrue);

      expect(harness.auth.calls.single, {
        'userId': 'user-1',
        'fullName': 'Ana María Gómez',
        'major': 'Ingeniería de Sistemas y Computación',
        'faculty': 'Ingeniería',
      });
      expect(vm.saved, isTrue);
      expect(vm.isSaving, isFalse);
      expect(harness.saved.single.fullName, 'Ana María Gómez');
      expect(await harness.storedDraft(), isNull);
      expect(vm.hasChanges, isFalse);
      vm.dispose();
    });

    test('an empty faculty is sent as null', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();
      await vm.setFaculty('   ');

      await vm.save();

      expect(harness.auth.calls.single['faculty'], isNull);
      vm.dispose();
    });

    test('offline at open -> online -> network lost during the PATCH', () async {
      final harness = _Harness(online: false);
      final vm = harness.viewModel();
      await vm.init();

      // Case A: offline from the start.
      expect(vm.isOnline, isFalse);
      await vm.setFullName('Ana Offline');
      expect(vm.canSave, isFalse);
      expect(vm.saveDisabledReason, EditProfileViewModel.offlineReason);
      expect(await vm.save(), isFalse);
      expect(harness.auth.calls, isEmpty);
      expect((await harness.storedDraft())?['fullName'], 'Ana Offline');

      // Case C: the connection comes back while on the screen.
      harness.network.set(true);
      await _settle();
      expect(vm.isOnline, isTrue);
      expect(vm.canSave, isTrue);
      expect(vm.saveDisabledReason, isNull);

      // Case D: the request cannot reach the server.
      harness.auth.next = const NetworkException('The server took too long to respond.');
      harness.auth.gate = Completer();
      final saving = vm.save();
      expect(vm.isSaving, isTrue);
      harness.auth.gate!.complete();
      expect(await saving, isFalse);

      expect(vm.isSaving, isFalse);
      expect(vm.saveError, EditProfileViewModel.networkErrorMessage);
      expect(vm.fullName, 'Ana Offline');
      expect((await harness.storedDraft())?['fullName'], 'Ana Offline');
      expect(harness.saved, isEmpty);
      vm.dispose();
    });

    test('losing the connection while editing disables Save and keeps what was typed', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();
      await vm.setFullName('Ana Editando');
      expect(vm.canSave, isTrue);

      // Case B.
      harness.network.set(false);
      await _settle();
      await vm.draftWritesDone;

      expect(vm.isOnline, isFalse);
      expect(vm.canSave, isFalse);
      expect(vm.fullName, 'Ana Editando');
      expect((await harness.storedDraft())?['fullName'], 'Ana Editando');
      vm.dispose();
    });

    test('back online after a network error, the error goes away and Save works', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();
      await vm.setFullName('Ana Reintento');
      harness.auth.next = const NetworkException('no network');
      await vm.save();
      expect(vm.saveError, isNotNull);

      harness.network.set(false);
      harness.network.set(true);
      await _settle();
      expect(vm.saveError, isNull);

      harness.auth.next = null;
      expect(await vm.save(), isTrue);
      vm.dispose();
    });

    test('a refusal from the server shows its message and keeps the draft', () async {
      final harness = _Harness();
      final vm = harness.viewModel();
      await vm.init();
      await vm.setFullName('Ana Rechazo');
      harness.auth.next = const ProfileUpdateException('Check your full name: use at least 2 letters.');

      expect(await vm.save(), isFalse);

      expect(vm.saveError, 'Check your full name: use at least 2 letters.');
      expect(vm.isSaving, isFalse);
      expect((await harness.storedDraft())?['fullName'], 'Ana Rechazo');
      vm.dispose();
    });

    test('a catalog that cannot be read leaves a usable form and can be retried', () async {
      var fail = true;
      final harness = _Harness(loadCatalog: () async {
        if (fail) throw StateError('asset missing');
        return _catalog;
      });
      final vm = harness.viewModel();
      await vm.init();

      expect(vm.isLoading, isFalse);
      expect(vm.catalogFailed, isTrue);
      expect(vm.major, 'ISIS');

      fail = false;
      await vm.retryCatalog();
      expect(vm.catalogFailed, isFalse);
      expect(vm.programs, hasLength(4));
      vm.dispose();
    });
  });

  group('EditProfileScreen', () {
    Future<_Harness> pump(WidgetTester tester, {bool online = true, VoidCallback? onClose}) async {
      final harness = _Harness(online: online);
      // The catalog is parsed in a real isolate, which only runs outside the fake clock; once
      // parsed it is answered from memory, so the screen loads instantly.
      await tester.runAsync(() => harness.programs.getPrograms());
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: EditProfileScreen(createViewModel: harness.viewModel, onClose: onClose ?? () {}),
      ));
      await tester.pumpAndSettle();
      return harness;
    }

    TextField field(WidgetTester tester, String key) => tester.widget<TextField>(
          find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)),
        );

    testWidgets('keyboard actions: next on the name, done on the faculty', (tester) async {
      await pump(tester);

      expect(field(tester, 'edit-profile-name').textInputAction, TextInputAction.next);
      expect(field(tester, 'edit-profile-faculty').textInputAction, TextInputAction.done);
      expect(find.text('ana@uniandes.edu.co'), findsOneWidget);
    });

    testWidgets('fields, picker and buttons have descriptive semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(find.bySemanticsLabel(RegExp(r'^Full name, 2 to 50 characters')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Major, ISIS\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Faculty, optional')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Save changes, disabled')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Back to profile')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Case A/C: offline banner at open, hidden when the connection is back', (tester) async {
      final harness = await pump(tester, online: false);

      expect(find.byKey(const Key('edit-profile-offline-banner')), findsOneWidget);
      await tester.enterText(find.descendant(of: find.byKey(const Key('edit-profile-name')), matching: find.byType(TextField)), 'Ana Sin Red');
      await tester.pump();
      expect(find.text(EditProfileViewModel.offlineReason), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      harness.network.set(true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-profile-offline-banner')), findsNothing);
      expect(find.byKey(const Key('edit-profile-save-reason')), findsNothing);
      expect((await harness.storedDraft())?['fullName'], 'Ana Sin Red');
    });

    testWidgets('Case D: a network failure on Save stops the spinner and keeps the text', (tester) async {
      final harness = await pump(tester);
      final name = find.descendant(of: find.byKey(const Key('edit-profile-name')), matching: find.byType(TextField));
      await tester.enterText(name, 'Ana Caída');
      await tester.pump();
      harness.auth.next = const NetworkException('timeout');

      await tester.tap(find.byKey(const Key('edit-profile-save')));
      await tester.pumpAndSettle();

      expect(find.text(EditProfileViewModel.networkErrorMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<TextField>(name).controller!.text, 'Ana Caída');
    });

    testWidgets('choosing a program in the searchable picker fills in the faculty', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('edit-profile-major-hint')), findsOneWidget); // legacy major

      await tester.tap(find.byKey(const Key('edit-profile-major')));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byKey(const Key('program-picker-search')), matching: find.byType(TextField)), 'electron');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('program-option-Economía')), findsNothing);

      await tester.tap(find.byKey(const Key('program-option-Ingeniería Electrónica')));
      await tester.pumpAndSettle();

      expect(find.text('Ingeniería Electrónica'), findsOneWidget);
      expect(field(tester, 'edit-profile-faculty').controller!.text, 'Ingeniería');
      expect(find.byKey(const Key('edit-profile-major-hint')), findsNothing);
    });

    testWidgets('a successful save shows a confirmation and closes the screen', (tester) async {
      var closed = 0;
      final harness = await pump(tester, onClose: () => closed++);
      await tester.enterText(find.descendant(of: find.byKey(const Key('edit-profile-name')), matching: find.byType(TextField)), 'Ana Nueva');
      await tester.pump();

      await tester.tap(find.byKey(const Key('edit-profile-save')));
      await tester.pumpAndSettle();

      expect(harness.auth.calls.single['fullName'], 'Ana Nueva');
      expect(find.byKey(const Key('profile-saved-snackbar')), findsOneWidget);
      expect(closed, 1);
    });
  });
}
