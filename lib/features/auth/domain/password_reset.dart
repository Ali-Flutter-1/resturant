import 'package:equatable/equatable.dart';

/// The short-lived credential from step 2 of the password reset.
///
/// Held in memory only — never written to secure storage, never logged. It is a
/// bearer credential for changing a password, so the less of its life it spends
/// anywhere durable, the better.
class PasswordResetSession extends Equatable {
  const PasswordResetSession({required this.token, required this.expiresAt});

  /// Built from the API's `expires_in` (seconds) at the moment the response
  /// arrives, so the screen can count down without re-deriving the deadline.
  factory PasswordResetSession.fromJson(Map<String, dynamic> json) {
    final seconds = (json['expires_in'] as num?)?.toInt() ?? 600;
    return PasswordResetSession(
      token: json['reset_token']?.toString() ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  final String token;
  final DateTime expiresAt;

  Duration get remaining {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get hasExpired => remaining == Duration.zero;

  /// Deliberately omits the token. This object ends up in error reports and
  /// debug output, and the token must not travel with it.
  @override
  String toString() => 'PasswordResetSession(expiresAt: $expiresAt)';

  @override
  List<Object?> get props => [token, expiresAt];
}

/// The API's `error.code` values for this flow, as the guide documents them.
///
/// Branching on a code rather than on a message: the messages are written for
/// people and may be reworded, and two of these are deliberately
/// indistinguishable by wording alone.
abstract final class ResetErrorCodes {
  /// Wrong code — *or* a wrong email, which returns the same thing so the app
  /// cannot be used to discover who has an account. Stay on the code screen.
  static const String codeInvalid = 'RESET_CODE_INVALID';

  /// Five wrong tries. The code is dead, and from here even the correct one is
  /// refused — so the only way on is to request a new code.
  static const String tooManyAttempts = 'TOO_MANY_ATTEMPTS';

  static const String codeExpired = 'RESET_CODE_EXPIRED';

  /// Used already, or the flow was restarted somewhere else.
  static const String tokenInvalid = 'RESET_TOKEN_INVALID';

  static const String tokenExpired = 'RESET_TOKEN_EXPIRED';

  static const String validationFailed = 'VALIDATION_FAILED';

  /// Whether this failure means the code screen cannot be retried and the user
  /// has to start again.
  static bool sendsUserBackToStart(String? code) =>
      code == tooManyAttempts ||
      code == codeExpired ||
      code == tokenInvalid ||
      code == tokenExpired;
}
