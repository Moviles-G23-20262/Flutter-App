/// What was typed in the sign-up form and not sent yet. Passwords are never part of it.
class RegistrationDraft {
  final String fullName;
  final String email;
  final String major;
  final String? faculty;

  const RegistrationDraft({
    this.fullName = '',
    this.email = '',
    this.major = '',
    this.faculty,
  });

  bool get isEmpty => fullName.isEmpty && email.isEmpty && major.isEmpty && faculty == null;
}
