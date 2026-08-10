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
