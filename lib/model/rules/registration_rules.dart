abstract final class RegistrationRules {
  static const String institutionalDomain = '@uniandes.edu.co';

  static const int minPasswordLength = 8;

  static const int maxPasswordLength = 72;

  static final RegExp _institutionalEmail = RegExp(
    r'^[^\s@]+@uniandes\.edu\.co$',
    caseSensitive: false,
  );

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String? validateFullName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Enter your full name.';
    if (name.length < 2) return 'Your name is too short.';
    return null;
  }

  static String? validateEmail(String? value) {
    final email = normalizeEmail(value ?? '');
    if (email.isEmpty) return 'Enter your institutional email.';
    if (!_institutionalEmail.hasMatch(email)) {
      return 'Use your institutional email (name$institutionalDomain).';
    }
    return null;
  }

  static String? validateMajor(String? value) {
    final major = (value ?? '').trim();
    if (major.isEmpty) return 'Enter your major.';
    if (major.length < 2) return 'Your major is too short.';
    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Create a password.';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (password.length > maxPasswordLength) {
      return 'Use at most $maxPasswordLength characters.';
    }
    return null;
  }

  static String? validateConfirmation(String? password, String? confirmation) {
    if ((confirmation ?? '').isEmpty) return 'Repeat your password.';
    if (password != confirmation) return 'Passwords do not match.';
    return null;
  }
}
