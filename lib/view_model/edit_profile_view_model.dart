import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/network/api_client.dart' show NetworkException;
import '../model/entities/profile_draft.dart';
import '../model/entities/uniandes_program.dart';
import '../model/entities/user_entity.dart';
import '../model/exceptions/auth_exceptions.dart';
import '../model/repositories/connectivity_repository.dart';
import '../model/rules/profile_rules.dart';
import '../model/use_cases/profile_use_cases.dart';

/// The Edit Profile form: name, major (from the Uniandes catalog) and faculty, saved with
/// `PATCH /users/:id`.
///
/// Built for an unreliable connection:
/// - what is typed goes to a draft on the phone at every change, and stays there until the server
///   accepts it or the user discards it;
/// - it follows [ConnectivityRepository]: offline, the screen shows a banner and Save is disabled
///   with the reason; back online, Save works again by itself;
/// - a request that cannot reach the server ([NetworkException], timeouts included) ends the
///   saving state, keeps the form and the draft and says what happened.
class EditProfileViewModel extends ChangeNotifier {
  static const String offlineReason =
      "You're offline. Your changes are kept on this phone; connect to the internet to save them.";
  static const String networkErrorMessage =
      "Couldn't reach the server, so nothing was saved. Your changes are kept on this phone; "
      'try again when the connection is back.';
  static const String invalidReason = 'Fix the highlighted fields to save.';
  static const String noChangesReason = 'Change something to save it.';
  static const String catalogErrorMessage = "Couldn't load the list of Uniandes programs.";

  final UpdateProfileUseCase updateProfile;
  final GetUniandesProgramsUseCase getPrograms;
  final SearchUniandesProgramsUseCase searchPrograms;
  final LoadProfileDraftUseCase loadDraft;
  final SaveProfileDraftUseCase saveDraft;
  final ClearProfileDraftUseCase clearDraft;
  final ConnectivityRepository connectivity;

  /// Told about the profile the server saved (the app then shows it everywhere).
  final void Function(UserEntity user)? onSaved;

  EditProfileViewModel({
    required UserEntity user,
    required this.updateProfile,
    required this.getPrograms,
    required this.searchPrograms,
    required this.loadDraft,
    required this.saveDraft,
    required this.clearDraft,
    required this.connectivity,
    this.onSaved,
  })  : _user = user,
        _fullName = user.fullName,
        _major = user.major,
        _faculty = user.faculty ?? '';

  UserEntity _user;
  String _fullName;
  String _major;
  String _faculty;

  List<UniandesProgram> _programs = const [];
  bool _catalogFailed = false;
  bool _loadingCatalog = false;
  bool _loading = true;
  bool _online = true;
  bool _saving = false;
  bool _saved = false;
  bool _restoredDraft = false;
  String? _saveError;
  bool _saveErrorIsNetwork = false;
  bool _disposed = false;
  bool _sawConnectivityEvent = false;

  StreamSubscription<bool>? _connectivitySubscription;
  Future<void> _draftWrites = Future.value();

  // ── State ─────────────────────────────────────────────────────────────────

  /// The profile as the server has it (updated after a successful save).
  UserEntity get user => _user;
  String get fullName => _fullName;
  String get major => _major;
  String get faculty => _faculty;

  /// True until the catalog and the draft have been read (both at once).
  bool get isLoading => _loading;
  bool get isOnline => _online;
  bool get isSaving => _saving;

  /// The server accepted the last save.
  bool get saved => _saved;

  /// The form was filled from a draft left on the phone by a previous visit.
  bool get restoredDraft => _restoredDraft;

  /// Why the last save failed, in words for the user; `null` when it did not fail.
  String? get saveError => _saveError;

  List<UniandesProgram> get programs => _programs;
  bool get catalogFailed => _catalogFailed;
  bool get isLoadingCatalog => _loadingCatalog;

  /// The catalog entry of the chosen major, or `null` when it is not in the catalog.
  UniandesProgram? get selectedProgram => _programs.where((p) => p.name == _major).firstOrNull;

  /// The major saved on the server is not an exact catalog name (from an older sign-up form). It
  /// is kept as it is until the user picks one from the catalog.
  bool get isLegacyMajor => _major.isNotEmpty && _major == _user.major && selectedProgram == null;

  // ── Validation (the same rules as the server's DTO) ─────────────────────────

  String get normalizedFullName => ProfileRules.normalize(_fullName);
  String get normalizedFaculty => ProfileRules.normalize(_faculty);

  String? get fullNameError => ProfileRules.validateFullName(_fullName);

  String? get majorError {
    final rule = ProfileRules.validateMajor(_major);
    if (rule != null) return _major.isEmpty ? 'Choose your major from the Uniandes programs.' : rule;
    // Only a catalog program, or the major the account already has, can be saved.
    if (selectedProgram == null && _major != _user.major) return 'Choose your major from the Uniandes programs.';
    return null;
  }

  String? get facultyError => ProfileRules.validateFaculty(_faculty);

  bool get isValid => fullNameError == null && majorError == null && facultyError == null;

  /// Something differs from the profile on the server.
  bool get hasChanges =>
      normalizedFullName != _user.fullName || _major != _user.major || normalizedFaculty != (_user.faculty ?? '');

  bool get canSave => !_loading && !_saving && _online && isValid && hasChanges;

  /// Why Save is disabled, to show under it; `null` while it can be pressed or is saving.
  String? get saveDisabledReason {
    if (_loading || _saving) return null;
    if (!_online) return offlineReason;
    if (!isValid) return invalidReason;
    if (!hasChanges) return noChangesReason;
    return null;
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Reads the catalog (parsed in a background isolate), the saved draft and the network state at
  /// the same time, then follows the connection. Always finishes: a failure of any of them leaves
  /// a usable form.
  Future<void> init() async {
    _connectivitySubscription ??= connectivity.watch().listen(_onConnectivity, onError: (_) {});
    final results = await Future.wait<Object?>([
      _loadCatalog(),
      _readDraft(),
      _readOnline(),
    ]);
    if (_disposed) return;
    final draft = results[1] as ProfileDraft?;
    // A connectivity event that arrived meanwhile is newer than the first check.
    if (!_sawConnectivityEvent) _online = results[2] as bool;
    if (draft != null && _differsFromUser(draft)) {
      _fullName = draft.fullName;
      _major = draft.major;
      _faculty = draft.faculty;
      _restoredDraft = true;
    }
    _loading = false;
    _notify();
  }

  Future<ProfileDraft?> _readDraft() async {
    try {
      return await loadDraft.execute(_user.id);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _readOnline() async {
    try {
      return await connectivity.isOnline();
    } catch (_) {
      return true; // Cannot tell: let the request decide.
    }
  }

  Future<void> _loadCatalog() async {
    _loadingCatalog = true;
    _catalogFailed = false;
    try {
      _programs = await getPrograms.execute();
    } catch (_) {
      _catalogFailed = true;
    } finally {
      _loadingCatalog = false;
    }
  }

  /// "Retry" on the major picker after the catalog could not be read.
  Future<void> retryCatalog() async {
    if (_loadingCatalog) return;
    final load = _loadCatalog();
    _notify();
    await load;
    _notify();
  }

  /// The programs matching what is typed in the picker; answered from memory once loaded.
  Future<List<UniandesProgram>> search(String query) async {
    try {
      return await searchPrograms.execute(query);
    } catch (_) {
      return const [];
    }
  }

  bool _differsFromUser(ProfileDraft draft) =>
      draft.fullName != _user.fullName || draft.major != _user.major || draft.faculty != (_user.faculty ?? '');

  // ── Editing ───────────────────────────────────────────────────────────────

  /// Each change is written to the draft; the returned future completes once it is.
  Future<void> setFullName(String value) => _edit(() => _fullName = value);

  Future<void> setFaculty(String value) => _edit(() => _faculty = value);

  /// A program from the catalog: the major, and its faculty filled in (still editable).
  Future<void> selectProgram(UniandesProgram program) => _edit(() {
        _major = program.name;
        _faculty = program.faculty;
      });

  Future<void> _edit(void Function() change) {
    change();
    _saved = false;
    if (_saveError != null && !_saveErrorIsNetwork) _saveError = null;
    _notify();
    return _persistDraft();
  }

  /// "Discard changes": the form shows the profile on the server again and the draft is deleted.
  Future<void> discardChanges() {
    _fullName = _user.fullName;
    _major = _user.major;
    _faculty = _user.faculty ?? '';
    _restoredDraft = false;
    _saveError = null;
    _saveErrorIsNetwork = false;
    _notify();
    return _queueDraftWrite(() => clearDraft.execute(_user.id));
  }

  Future<void> _persistDraft() => _queueDraftWrite(
        () => saveDraft.execute(_user.id, ProfileDraft(fullName: _fullName, major: _major, faculty: _faculty)),
      );

  /// Draft writes run one after another, so an older one never overwrites a newer one (or
  /// brings back a draft that was just cleared).
  Future<void> _queueDraftWrite(Future<void> Function() write) {
    return _draftWrites = _draftWrites.then((_) async {
      try {
        await write();
      } catch (_) {
        // The draft is a convenience: the form keeps working without it.
      }
    });
  }

  /// Completes once every draft write asked for so far is done.
  Future<void> get draftWritesDone => _draftWrites;

  void _onConnectivity(bool online) {
    _sawConnectivityEvent = true;
    if (online == _online) return;
    _online = online;
    if (!online) {
      // Signal lost mid-edit: what is on screen is (again) on the phone.
      _persistDraft();
    } else if (_saveErrorIsNetwork) {
      // Back online: the network error no longer applies, Save is enabled again.
      _saveError = null;
      _saveErrorIsNetwork = false;
    }
    _notify();
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  /// Sends name, major and faculty. Returns whether the server saved them. Never leaves the form
  /// in the saving state.
  Future<bool> save() async {
    if (!canSave) return false;
    _saving = true;
    _saveError = null;
    _saveErrorIsNetwork = false;
    _notify();
    try {
      final faculty = normalizedFaculty;
      final updated = await updateProfile.execute(
        userId: _user.id,
        fullName: normalizedFullName,
        major: _major,
        faculty: faculty.isEmpty ? null : faculty,
      );
      _user = updated;
      _fullName = updated.fullName;
      _major = updated.major;
      _faculty = updated.faculty ?? '';
      _restoredDraft = false;
      _saved = true;
      await _queueDraftWrite(() => clearDraft.execute(updated.id));
      onSaved?.call(updated);
      return true;
    } on NetworkException {
      _saveError = networkErrorMessage;
      _saveErrorIsNetwork = true;
      await _persistDraft();
      return false;
    } on AuthException catch (e) {
      _saveError = e.message;
      return false;
    } catch (_) {
      _saveError = 'Something went wrong and nothing was saved. Please try again.';
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
