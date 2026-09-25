class User {
  final String id;
  final String email;
  final String fullName;
  final String major;
  final String? faculty;
  final double rating;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.major,
    this.faculty,
    required this.rating,
    required this.createdAt,
  });
}