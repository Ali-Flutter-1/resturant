import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/token_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

/// The HTTP implementation of [AuthRepository].
///
/// Covers everything under `/auth` and the parts of `/profile` that change a
/// session.
///
/// The repository owns one rule the rest of the app should not have to think
/// about: **tokens are saved here and nowhere else.** Register, login, Google
/// sign-in and change-password all return a fresh pair, and every one of them
/// funnels through [_storeSession]. A cubit that had to remember to persist
/// tokens would eventually forget on one path.
///
/// Failures are left as [ApiFailure] and not caught. They already carry a
/// message fit to show a person, so translating them again here would only
/// throw information away.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required ApiClient client, required TokenStore tokens})
    : _client = client,
      _tokens = tokens;

  final ApiClient _client;
  final TokenStore _tokens;

  @override
  bool get hasStoredSession => _tokens.hasSession;

  /// Creates an account and signs the new user in.
  @override
  Future<AuthUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final data = await _client.object(
      ApiConstants.register,
      method: 'POST',
      body: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return _storeSession(data);
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.object(
      ApiConstants.login,
      method: 'POST',
      // Email is trimmed and lower-cased so a stray capital or a copy-paste
      // space isn't reported back as "no account for that email".
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return _storeSession(data);
  }

  /// Signs in with the ID token from `google_sign_in`.
  @override
  Future<AuthUser> signInWithGoogle(String idToken) async {
    final data = await _client.object(
      ApiConstants.google,
      method: 'POST',
      body: {'id_token': idToken},
    );
    return _storeSession(data);
  }

  /// The current user, for restoring a session at startup.
  @override
  Future<AuthUser> currentUser() async {
    final data = await _client.object(ApiConstants.me);
    return AuthUser.fromJson(data);
  }

  /// Revokes this device's refresh token, then forgets it locally.
  ///
  /// The local clear happens whatever the server says. A failed logout call
  /// must still sign the user out of this device — leaving them apparently
  /// signed in because the network hiccuped would be the wrong way to fail.
  @override
  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    try {
      if (refresh != null) {
        await _client.object(
          ApiConstants.logout,
          method: 'POST',
          body: {'refresh_token': refresh},
        );
      }
    } on ApiFailure {
      // Deliberately ignored; see above.
    } finally {
      await _tokens.clear();
    }
  }

  /// Always reports success, whether or not the address is registered — the API
  /// is deliberately silent about which addresses exist, and the UI must not
  /// undo that by saying "no such account".
  @override
  Future<void> requestPasswordReset(String email) async {
    await _client.object(
      ApiConstants.forgotPassword,
      method: 'POST',
      body: {'email': email.trim()},
    );
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _client.object(
      ApiConstants.resetPassword,
      method: 'POST',
      body: {'token': token, 'new_password': newPassword},
    );
  }

  /// Changes the password and adopts the new token pair the API returns.
  ///
  /// The old sessions are revoked server-side, so failing to store the new
  /// tokens would sign this device out a moment later.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _client.object(
      ApiConstants.changePassword,
      method: 'POST',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    if (access is String && refresh is String) {
      await _tokens.save(accessToken: access, refreshToken: refresh);
    }
  }

  /// Reads the `{user, tokens}` shape returned by every sign-in route, stores
  /// the pair, and hands back the user.
  Future<AuthUser> _storeSession(Map<String, dynamic> data) async {
    final tokens = data['tokens'];
    if (tokens is Map) {
      final access = tokens['access_token'];
      final refresh = tokens['refresh_token'];
      if (access is String && refresh is String) {
        await _tokens.save(accessToken: access, refreshToken: refresh);
      }
    }

    final user = data['user'];
    if (user is Map) return AuthUser.fromJson(Map<String, dynamic>.from(user));

    // Some deployments return only tokens. Asking who we are is cheaper than
    // guessing, and the role decides which half of the app opens.
    return currentUser();
  }
}
