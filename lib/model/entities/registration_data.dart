class RegistrationData {
  final String email;

  final String password;

  final String fullName;
  final String major;

  final String? faculty;

  const RegistrationData({
    required this.email,
    required this.password,
    required this.fullName,
    required this.major,
    this.faculty,
  });
}
