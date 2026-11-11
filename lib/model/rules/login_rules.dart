import 'input_rules.dart';
import 'registration_rules.dart';

/// Input rules of the login form. Stricter than the server (which only needs a valid email
/// and 1 to 72 characters), but never stricter than what sign-up already guarantees, so every
/// real account can still log in. Sign-up's institutional-domain rule does not apply here.
abstract final class LoginRules {
  static const int minPasswordLength = RegistrationRules.minPasswordLength;
  static const int maxPasswordLength = RegistrationRules.maxPasswordLength;
  static const int maxEmailLength = InputRules.maxEmailLength;

  /// The emoji set lives in [InputRules] (shared with sign-up); kept here for the login form.
  static final RegExp emoji = InputRules.emoji;

  /// `user@domain.tld`: a plain local part, dot-separated domain labels and a letters-only
  /// top-level domain of 2+ characters.
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  static bool containsEmoji(String text) => InputRules.containsEmoji(text);

  /// The email as it is sent: no surrounding whitespace, lower case.
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String? validateEmail(String? value) {
    final raw = value ?? '';
    final email = raw.trim();
    if (email.isEmpty) return 'Enter your email.';
    if (containsEmoji(email)) return "The email can't contain emojis.";
    if (email.length > maxEmailLength || !_email.hasMatch(email)) {
      return 'Enter a valid email, like name@domain.com.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter your password.';
    if (password.trim().isEmpty) return "The password can't be only spaces.";
    if (containsEmoji(password)) return "The password can't contain emojis.";
    if (password.length < minPasswordLength) return 'Use at least $minPasswordLength characters.';
    if (password.length > maxPasswordLength) return 'Use at most $maxPasswordLength characters.';
    return null;
  }
}
