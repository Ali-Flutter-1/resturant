import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Who is using the app.
enum UserRole { customer, admin }

class AuthState extends Equatable {
  const AuthState({
    this.role,
    this.email,
    this.isSubmitting = false,
    this.error,
  });

  /// Null means signed out.
  final UserRole? role;
  final String? email;
  final bool isSubmitting;
  final String? error;

  bool get isSignedIn => role != null;

  AuthState copyWith({
    UserRole? role,
    String? email,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool signOut = false,
  }) {
    return AuthState(
      role: signOut ? null : (role ?? this.role),
      email: signOut ? null : (email ?? this.email),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError || signOut ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [role, email, isSubmitting, error];
}

/// A stand-in for authentication so both roles can be exercised before the
/// API exists.
///
/// **This is throwaway.** There is no network call, no token, no refresh, no
/// persistence — sign-in is decided by matching the email against a hard-coded
/// pair below. When the real contract arrives, replace the body of [signIn]
/// with the repository call and delete [demoAccounts]; the rest of the app
/// only reads [AuthState.role] and does not care how it was set.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({this.latency = const Duration(milliseconds: 450)})
    : super(const AuthState());

  /// Stand-in for network round-trip time, so the button's loading state is
  /// visible. Tests pass [Duration.zero] rather than leaving a timer pending
  /// against the fake clock.
  final Duration latency;

  static const demoAccounts = <String, UserRole>{
    'customer@tscafe.co.uk': UserRole.customer,
    'admin@tscafe.co.uk': UserRole.admin,
  };

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final normalised = email.trim().toLowerCase();
    final role = demoAccounts[normalised];

    if (role == null) {
      emit(
        state.copyWith(
          isSubmitting: false,
          error:
              'No account for that email. Try one of the demo accounts below.',
        ),
      );
      return;
    }
    if (password.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          error: 'Enter any password — this build does not check it.',
        ),
      );
      return;
    }

    emit(AuthState(role: role, email: normalised));
  }

  /// One-tap entry, so switching roles while testing is not a typing exercise.
  void signInAs(UserRole role) {
    final email = demoAccounts.entries
        .firstWhere((entry) => entry.value == role)
        .key;
    emit(AuthState(role: role, email: email));
  }

  void signOut() => emit(const AuthState());
}
