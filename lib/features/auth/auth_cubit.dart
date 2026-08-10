import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_failure.dart';
import 'domain/auth_repository.dart';
import 'domain/auth_user.dart';

export 'domain/auth_user.dart' show AuthUser, UserRole;

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isSubmitting = false,
    this.isRestoring = false,
    this.error,
    this.errorIsRetryable = false,
    this.fieldErrors = const {},
  });

  /// Null means signed out.
  final AuthUser? user;

  final bool isSubmitting;

  /// True while a stored session is being checked at startup, so the app can
  /// hold the splash rather than flashing the login screen at someone who is
  /// already signed in.
  final bool isRestoring;

  /// Safe to show verbatim; it comes from [ApiFailure.message].
  final String? error;

  /// Whether offering "Try again" makes sense for this error.
  final bool errorIsRetryable;

  /// Per-field complaints from the API, keyed by its field names.
  final Map<String, String> fieldErrors;

  UserRole? get role => user?.role;
  String? get email => user?.email;
  bool get isSignedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isSubmitting,
    bool? isRestoring,
    String? error,
    bool? errorIsRetryable,
    Map<String, String>? fieldErrors,
    bool clearError = false,
    bool signOut = false,
  }) {
    return AuthState(
      user: signOut ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRestoring: isRestoring ?? this.isRestoring,
      error: clearError || signOut ? null : (error ?? this.error),
      errorIsRetryable: clearError || signOut
          ? false
          : (errorIsRetryable ?? this.errorIsRetryable),
      fieldErrors: clearError || signOut
          ? const {}
          : (fieldErrors ?? this.fieldErrors),
    );
  }

  @override
  List<Object?> get props => [
    user,
    isSubmitting,
    isRestoring,
    error,
    errorIsRetryable,
    fieldErrors,
  ];
}

/// The session.
///
/// Talks to [AuthRepository] and holds nothing the rest of the app doesn't need.
/// Every failure arrives as an [ApiFailure] whose message is already fit to
/// show, so this class never composes error text of its own — doing so is how
/// apps end up telling users about status codes.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({AuthRepository? repository, AuthUser? initialUser})
    : _repository = repository,
      super(AuthState(user: initialUser));

  /// Null only where sign-in cannot be attempted — a preview, or a test that
  /// starts from [initialUser] and never calls the network.
  final AuthRepository? _repository;

  /// Restores a stored session, if there is one.
  ///
  /// Called once at startup. A failure here is not worth showing: being signed
  /// out is a normal state, and an error banner on first launch would be
  /// alarming and useless.
  Future<void> restore() async {
    final repository = _repository;
    if (repository == null || !repository.hasStoredSession) return;

    emit(state.copyWith(isRestoring: true));
    try {
      final user = await repository.currentUser();
      emit(AuthState(user: user));
    } on ApiFailure {
      emit(const AuthState());
    }
  }

  /// Drops any error and field complaints left over from a previous attempt.
  ///
  /// Sign-in and sign-up share one cubit, so a failure on one screen was
  /// rendering the moment the other opened — which looked exactly like the
  /// second screen having submitted by itself. Each screen clears on entry.
  void clearError() {
    if (state.error == null && state.fieldErrors.isEmpty) return;
    emit(state.copyWith(clearError: true));
  }

  Future<void> signIn({required String email, required String password}) =>
      _attempt(() => _repository!.login(email: email, password: password));

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) => _attempt(
    () => _repository!.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    ),
  );

  Future<void> signInWithGoogle(String idToken) =>
      _attempt(() => _repository!.signInWithGoogle(idToken));

  /// Runs a sign-in attempt and reports it uniformly.
  Future<void> _attempt(Future<AuthUser> Function() action) async {
    if (_repository == null) {
      emit(
        state.copyWith(
          error: 'Sign-in is not available in this build.',
          isSubmitting: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      emit(AuthState(user: await action()));
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          isSubmitting: false,
          error: failure.message,
          errorIsRetryable: failure.isRetryable,
          fieldErrors: failure.fieldErrors,
        ),
      );
    }
  }

  /// Signs out of this device.
  ///
  /// The local state clears immediately rather than after the round trip: the
  /// user asked to leave, and making them watch a spinner to do it — or leaving
  /// them signed in because the request failed — would both be wrong.
  Future<void> signOut() async {
    emit(const AuthState());
    await _repository?.logout();
  }

  /// Requests a reset email. Reports the API's own wording, which is
  /// deliberately the same whether or not the address exists.
  Future<String?> requestPasswordReset(String email) async {
    try {
      await _repository?.requestPasswordReset(email);
      return null;
    } on ApiFailure catch (failure) {
      return failure.message;
    }
  }
}
