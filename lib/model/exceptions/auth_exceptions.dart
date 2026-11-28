import 'data_exceptions.dart';

sealed class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

final class InvalidRegistrationException extends AuthException {
  const InvalidRegistrationException(super.message);
}
final class EmailAlreadyRegisteredException extends AuthException {
  const EmailAlreadyRegisteredException()
      : super('An account with this email already exists.');
}

/// The login form was filled in wrongly (bad email format, emojis, short password...).
/// Raised before any request is made.
final class InvalidLoginInputException extends AuthException {
  const InvalidLoginInputException(super.message);
}

final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException() : super('Incorrect email or password.');
}

final class AuthNetworkException extends AuthException {
  const AuthNetworkException()
      : super(checkInternetMessage);
}

/// The server refused a profile edit; [message] says why, in words for the user.
final class ProfileUpdateException extends AuthException {
  const ProfileUpdateException(super.message);
}

final class AuthServerException extends AuthException {
  const AuthServerException([
    super.message = temporarilyUnavailableMessage,
  ]);
}
