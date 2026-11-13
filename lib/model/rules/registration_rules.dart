import 'input_rules.dart';

/// Input rules of the sign-up form. Stricter than the server (which only needs a valid email,
/// 2 to 50 characters for the name, up to 50 for the major and 8 to 72 for the password), so nothing Flutter lets through is
/// refused with a 400. Login does not use the password complexity rules: accounts created
/// before them must still be able to sign in.
abstract final class RegistrationRules {
  static const String institutionalDomain = '@uniandes.edu.co';

  static const int minPasswordLength = 8;

  /// bcrypt only uses the first 72 bytes; the password is ASCII only, so 72 characters = 72 bytes.
  static const int maxPasswordLength = 72;

  static const int minLetters = 2;
  static const int maxNameLength = 50;
  static const int maxMajorLength = 50;

  /// The local part of an email is at most 64 characters.
  static const int maxEmailLocalLength = 64;

  /// Dot-separated groups, so ".ana", "ana." and "a..b" are refused (the server refuses them too).
  static final RegExp _institutionalEmail = RegExp(
    r'^[a-zA-Z0-9%+_-]+(?:\.[a-zA-Z0-9%+_-]+)*@uniandes\.edu\.co$',
  );

  static final RegExp _whitespace = RegExp(r'\s');
  static final RegExp _manySpaces = RegExp(r'\s+');

  /// Control and invisible characters. Plain whitespace is collapsed before this is checked.
  static final RegExp _invisible = InputRules.controlOrInvisible;

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Letters (with accents and combining marks), single spaces, "." and "-".
  static final RegExp _nameCharacters = RegExp(r'^[\p{L}\p{M} .\-]+$', unicode: true);

  /// Printable ASCII without the space: 1 character is 1 byte for bcrypt.
  static final RegExp _passwordCharacters = RegExp(r'^[\x21-\x7E]+$');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');

  /// Any printable ASCII that is not a letter or a digit: ! " # $ % & ' ( ) * + , - . / : ; < = > ? @ [ \ ] ^ _ ` { | } ~
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  // ── Normalization (what is sent to the server) ────────────────────────────

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  /// Trimmed, with runs of whitespace collapsed into one space. For names and majors.
  static String normalizeText(String raw) => raw.trim().replaceAll(_manySpaces, ' ');

  static String normalizeName(String raw) => normalizeText(raw);

  // ── Validation ─────────────────────────────────────────────────────────────

  static String? validateFullName(String? value) {
    final name = normalizeName(value ?? '');
    if (name.isEmpty) return 'Enter your full name.';
    if (InputRules.containsEmoji(name)) return "Your name can't contain emojis.";
    if (_invisible.hasMatch(name)) return 'Your name has characters that are not allowed.';
    if (!_nameCharacters.hasMatch(name)) {
      return 'Use only letters, spaces, periods and hyphens in your name.';
    }
    if (_letters(name) < minLetters) return 'Your name needs at least $minLetters letters.';
    if (name.length > maxNameLength) return 'Your name is too long (at most $maxNameLength characters).';
    return null;
  }

  static String? validateEmail(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Enter your institutional email.';
    if (_whitespace.hasMatch(raw)) return "The email can't contain spaces.";
    if (InputRules.containsEmoji(raw)) return "The email can't contain emojis.";
    final email = normalizeEmail(raw);
    final local = email.split('@').first;
    if (email.length > InputRules.maxEmailLength || local.length > maxEmailLocalLength) {
      return 'The email is too long.';
    }
    if (!_institutionalEmail.hasMatch(email)) {
      return 'Use your institutional email (name$institutionalDomain).';
    }
    return null;
  }

  static String? validateMajor(String? value) {
    final major = normalizeText(value ?? '');
    if (major.isEmpty) return 'Enter your major.';
    if (InputRules.containsEmoji(major)) return "Your major can't contain emojis.";
    if (_invisible.hasMatch(major)) return 'Your major has characters that are not allowed.';
    if (_letters(major) < minLetters) return 'Your major needs at least $minLetters letters.';
    if (major.length > maxMajorLength) return 'Your major is too long (at most $maxMajorLength characters).';
    return null;
  }

  /// [email] and [fullName], when given, must not be the password itself.
  static String? validatePassword(String? value, {String? email, String? fullName}) {
    final password = value ?? '';
    if (password.isEmpty) return 'Create a password.';
    if (_whitespace.hasMatch(password)) return "The password can't contain spaces.";
    if (InputRules.containsEmoji(password)) return "The password can't contain emojis.";
    if (!_passwordCharacters.hasMatch(password)) {
      return 'Use only letters without accents, numbers and symbols (no invisible characters).';
    }
    if (password.length < minPasswordLength) return 'Use at least $minPasswordLength characters.';
    if (password.length > maxPasswordLength) return 'Use at most $maxPasswordLength characters.';

    // Before the complexity: "Add a number" would be a poor answer to a password that is the email.
    final lower = password.toLowerCase();
    if (email != null && lower == normalizeEmail(email)) {
      return "The password can't be the same as your email.";
    }
    if (fullName != null) {
      final name = normalizeName(fullName).toLowerCase();
      if (name.isNotEmpty && (lower == name || lower == name.replaceAll(' ', ''))) {
        return "The password can't be the same as your name.";
      }
    }

    final missing = <String>[
      if (!_upper.hasMatch(password)) 'an uppercase letter',
      if (!_lower.hasMatch(password)) 'a lowercase letter',
      if (!_digit.hasMatch(password)) 'a number',
      if (!_symbol.hasMatch(password)) 'a symbol',
    ];
    if (missing.isNotEmpty) return 'Add ${_listOf(missing)}.';
    return null;
  }

  static String? validateConfirmation(String? password, String? confirmation) {
    if ((confirmation ?? '').isEmpty) return 'Repeat your password.';
    if (password != confirmation) return 'Passwords do not match.';
    return null;
  }

  static int _letters(String text) => _letter.allMatches(text).length;

  /// "a", "a and b", "a, b and c".
  static String _listOf(List<String> items) {
    if (items.length == 1) return items.single;
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
}
