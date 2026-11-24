import 'package:flutter/foundation.dart';

/// The profile edit not saved to the server yet: what is typed in the Edit Profile form.
@immutable
class ProfileDraft {
  final String fullName;
  final String major;
  final String faculty;

  const ProfileDraft({required this.fullName, required this.major, required this.faculty});

  @override
  bool operator ==(Object other) =>
      other is ProfileDraft && other.fullName == fullName && other.major == major && other.faculty == faculty;

  @override
  int get hashCode => Object.hash(fullName, major, faculty);
}
