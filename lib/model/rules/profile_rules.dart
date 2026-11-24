import 'input_rules.dart';
import 'registration_rules.dart';

/// Input rules of the Edit Profile form, the same as the server's `UpdateUserDto` (which reuses
/// the sign-up DTO): name and major follow [RegistrationRules]; the faculty is optional, at most
/// [maxFacultyLength] characters and without control or invisible characters.
abstract final class ProfileRules {
  static const int maxNameLength = RegistrationRules.maxNameLength;
  static const int maxMajorLength = RegistrationRules.maxMajorLength;
  static const int maxFacultyLength = 80;

  /// Trimmed, with every run of whitespace turned into one space (what the server stores).
  static String normalize(String raw) => RegistrationRules.normalizeText(raw);

  /// 2 to 50 characters; letters (accents and ñ included), spaces, "." and "-"; at least 2 letters.
  static String? validateFullName(String? value) => RegistrationRules.validateFullName(value);

  /// Required, at most 50 characters, at least 2 letters, no emojis or control characters.
  static String? validateMajor(String? value) => RegistrationRules.validateMajor(value);

  static String? validateFaculty(String? value) {
    final faculty = normalize(value ?? '');
    if (faculty.isEmpty) return null;
    if (InputRules.controlOrInvisible.hasMatch(faculty)) return 'Your faculty has characters that are not allowed.';
    if (faculty.length > maxFacultyLength) {
      return 'Your faculty is too long (at most $maxFacultyLength characters).';
    }
    return null;
  }
}
