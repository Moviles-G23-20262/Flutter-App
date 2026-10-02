import '../../Domain/Entities/user_entity.dart';

/// Body of `POST /auth/login` and `POST /auth/register`: `{ user, accessToken }`.
class AuthSessionModel {
  final UserEntity user;
  final String accessToken;

  const AuthSessionModel({required this.user, required this.accessToken});

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      user: userEntityFromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String,
    );
  }
}

UserEntity userEntityFromJson(Map<String, dynamic> json) {
  return UserEntity(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    major: json['major'] as String,
    faculty: json['faculty'] as String?,
    rating: (json['rating'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
