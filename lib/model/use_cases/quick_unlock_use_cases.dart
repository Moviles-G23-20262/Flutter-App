import '../entities/user_entity.dart';
import '../exceptions/auth_exceptions.dart';
import '../repositories/auth_repository.dart';
import '../repositories/biometric_authenticator.dart';

/// What the login screen shows for Quick Unlock: the account that was enrolled.
class QuickUnlockOffer {
  final String? email;

  const QuickUnlockOffer({this.email});
}

/// Whether the login screen can offer "Quick Unlock": the phone has an enrolled fingerprint AND
/// an account was enrolled on this device. It does not depend on a session being open, so it
/// is still offered after "Sign Out". Null when it cannot be offered.
class CanQuickUnlockUseCase {
  final BiometricAuthenticator biometrics;
  final AuthRepository auth;

  CanQuickUnlockUseCase({required this.biometrics, required this.auth});

  Future<QuickUnlockOffer?> execute() async {
    try {
      if (!await biometrics.canCheckBiometrics()) return null;
      if (!await auth.hasEnrolledBiometricCredential()) return null;
      return QuickUnlockOffer(email: await auth.enrolledEmail());
    } catch (_) {
      return null;
    }
  }
}

enum QuickUnlockOutcome {
  /// Verified and signed back in.
  unlocked,

  /// The user cancelled or the sensor did not recognise them.
  notVerified,

  /// Verified, but the server no longer accepts the saved credential: the password is needed.
  /// The credential has been forgotten.
  credentialRejected,

  /// Verified, but the account could not be reached (offline, server error). Try again later.
  unreachable,
}

class QuickUnlockResult {
  final QuickUnlockOutcome outcome;
  final UserEntity? user;

  /// Something to tell the user for [QuickUnlockOutcome.unreachable].
  final String? message;

  const QuickUnlockResult(this.outcome, {this.user, this.message});
}

/// Fingerprint first; only then is the stored biometric credential used to bring the account
/// back. Never throws.
class QuickUnlockUseCase {
  final BiometricAuthenticator biometrics;
  final AuthRepository auth;

  QuickUnlockUseCase({required this.biometrics, required this.auth});

  Future<QuickUnlockResult> execute() async {
    try {
      if (!await biometrics.authenticate()) {
        return const QuickUnlockResult(QuickUnlockOutcome.notVerified);
      }
      final user = await auth.restoreWithBiometricCredential();
      return user == null
          ? const QuickUnlockResult(QuickUnlockOutcome.credentialRejected)
          : QuickUnlockResult(QuickUnlockOutcome.unlocked, user: user);
    } on AuthException catch (e) {
      return QuickUnlockResult(QuickUnlockOutcome.unreachable, message: e.message);
    } catch (_) {
      return const QuickUnlockResult(
        QuickUnlockOutcome.unreachable,
        message: 'Something went wrong. Please try again.',
      );
    }
  }
}

/// "Sign in with a different account": forgets the fingerprint account on this device.
class ForgetBiometricsUseCase {
  final AuthRepository auth;

  ForgetBiometricsUseCase(this.auth);

  Future<void> execute() => auth.forgetBiometrics();
}
