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

final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException() : super('Incorrect email or password.');
}

final class AuthNetworkException extends AuthException {
  const AuthNetworkException()
      : super("Can't reach the server. Check your connection and try again.");
}

final class AuthServerException extends AuthException {
  const AuthServerException([
    super.message = 'Something went wrong on our side. Please try again later.',
  ]);
}
