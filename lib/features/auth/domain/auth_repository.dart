import 'auth_user.dart';

/// What the session needs from the outside world.
///
/// An interface rather than a concrete class so the cubit can be exercised
/// without a server — and so swapping the transport later (or adding a caching
/// layer in front of it) doesn't touch the cubit at all.
abstract interface class AuthRepository {
  /// Whether a refresh token survived the last run, and a session is therefore
  /// worth trying to restore.
  bool get hasStoredSession;

  Future<AuthUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<AuthUser> login({required String email, required String password});

  Future<AuthUser> signInWithGoogle(String idToken);

  Future<AuthUser> currentUser();

  Future<void> logout();

  /// Closes the account for good and signs this device out.
  ///
  /// Separate from [logout] because it is not a session operation: the server
  /// deletes the user, so there is nothing left to sign back in to.
  ///
  /// The current password is required — a valid access token alone is not
  /// enough to destroy an account, so an unlocked phone left on a table cannot
  /// be used to close someone's account.
  Future<void> deleteAccount(String password);

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
