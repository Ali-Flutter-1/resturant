import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/auth/domain/auth_repository.dart';

/// A repository that answers from a script.
///
/// The cubit's job is to turn repository outcomes into state, so the tests drive
/// it with outcomes rather than with a server. Every route records what it was
/// given, because most of what is worth asserting about auth is *what reached the
/// server* — a confirmation prompt that never sends the password is theatre, and
/// a test that only checks the UI would not notice.
///
/// [failure] is mutable so one test can succeed and then fail without building a
/// second repository, which is how the interesting sequences work: sign in, then
/// have the delete refused.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user = defaultUser, this.failure});

  static const defaultUser = AuthUser(
    id: 'u1',
    email: 'ali@example.com',
    firstName: 'Ali',
    lastName: 'Hassan',
    role: UserRole.customer,
  );

  /// Returned by every sign-in route and by [currentUser].
  AuthUser? user;

  /// Thrown instead, when set.
  ApiFailure? failure;

  bool storedSession = true;

  @override
  bool get hasStoredSession => storedSession;

  int logoutCalls = 0;
  int currentUserCalls = 0;
  int deleteCalls = 0;
  int resetCalls = 0;
  String? lastEmail;
  String? lastPassword;
  String? deletedWithPassword;
  String? resetToken;
  String? resetNewPassword;
  String? forgotEmail;
  String? changedFrom;
  String? changedTo;

  Future<AuthUser> _answer() async {
    final error = failure;
    if (error != null) throw error;
    return user!;
  }

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return _answer();
  }

  @override
  Future<AuthUser> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    lastEmail = email;
    lastPassword = password;
    return _answer();
  }

  @override
  Future<AuthUser> signInWithGoogle(String idToken) => _answer();

  @override
  Future<AuthUser> currentUser() {
    currentUserCalls++;
    return _answer();
  }

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<void> deleteAccount(String password) async {
    deleteCalls++;
    final error = failure;
    if (error != null) throw error;
    deletedWithPassword = password;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    forgotEmail = email;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    resetCalls++;
    final error = failure;
    if (error != null) throw error;
    resetToken = token;
    resetNewPassword = newPassword;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final error = failure;
    if (error != null) throw error;
    changedFrom = currentPassword;
    changedTo = newPassword;
  }
}
