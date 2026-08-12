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

  String? updatedFirstName;
  String? updatedLastName;

  @override
  Future<AuthUser> updateProfile({String? firstName, String? lastName}) async {
    final error = failure;
    if (error != null) throw error;
    updatedFirstName = firstName;
    updatedLastName = lastName;
    final current = user ?? defaultUser;
    // Returns the *stored* user, so a test can prove the screen adopts what the
    // server sent back rather than the strings that were typed in.
    user = AuthUser(
      id: current.id,
      email: current.email,
      firstName: firstName ?? current.firstName,
      lastName: lastName ?? current.lastName,
      role: current.role,
      avatarUrl: current.avatarUrl,
    );
    return user!;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    forgotEmail = email;
    final error = failure;
    if (error != null) throw error;
  }

  /// The failure the *code* step should answer with, separate from [failure] so
  /// a test can let step 1 succeed and have step 2 refuse.
  ApiFailure? verifyFailure;
  String? verifiedEmail;
  String? verifiedCode;
  int verifyCalls = 0;

  /// What a successful verification hands back.
  PasswordResetSession session = PasswordResetSession(
    token: 'reset-token-abc',
    expiresAt: DateTime.now().add(const Duration(minutes: 10)),
  );

  @override
  Future<PasswordResetSession> verifyResetCode({
    required String email,
    required String code,
  }) async {
    verifyCalls++;
    verifiedEmail = email;
    verifiedCode = code;
    final error = verifyFailure ?? failure;
    if (error != null) throw error;
    return session;
  }

  int forgetCalls = 0;

  @override
  Future<void> forgetSession() async => forgetCalls++;

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
