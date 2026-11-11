/// Turns the raw 400 text of the server's validator (one message per line, like
/// `password must be longer than or equal to 8 characters`) into text a student can act on.
abstract final class ApiValidationMessages {
  static const String generic = 'Some of the information is not valid. Please review it and try again.';

  /// The field a validator line talks about: its first word (`email`, `password`, `fullName`...).
  static final RegExp _line = RegExp(r'^(\w+)\s+(?:must|should)\b(.*)$', caseSensitive: false);

  /// [registration] picks the wording for the email: sign-up needs the institutional one.
  static String friendly(String raw, {bool registration = false}) {
    final messages = <String>{};
    for (final line in raw.split('\n')) {
      final match = _line.firstMatch(line.trim());
      messages.add(match == null ? generic : _forField(match.group(1)!, match.group(2)!, registration));
    }
    messages.remove(generic);
    if (messages.isEmpty) return generic;
    return messages.join('\n');
  }

  static String _forField(String field, String rule, bool registration) {
    switch (field) {
      case 'email':
        return registration
            ? 'Use your institutional email (name@uniandes.edu.co).'
            : 'Enter a valid email, like name@domain.com.';
      case 'password':
        if (rule.contains('longer')) return 'Your password is too short (at least 8 characters).';
        if (rule.contains('shorter')) return 'Your password is too long (at most 72 characters).';
        return 'Check your password.';
      case 'fullName':
        return 'Check your full name: use at least 2 letters.';
      case 'major':
        return 'Check your major.';
      case 'faculty':
        return 'Check your faculty.';
      default:
        return generic;
    }
  }
}
