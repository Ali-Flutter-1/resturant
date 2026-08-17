import 'package:flutter/widgets.dart';
// `flutter_bloc` re-exports provider's `context.read` and the exception it
// throws when nothing is in scope, so the package is not a direct dependency.
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';

/// Runs a screen's own reload and re-reads the session alongside it.
///
/// Pull-to-refresh means "show me what's true now", and the signed-in person's
/// role is part of that. It used to be re-read on the Profile screen only, so an
/// admin promoting somebody to staff reached their app only if they happened to
/// pull *there* — anywhere else they kept the customer tab bar, and a
/// deactivated account kept browsing until an unrelated request failed.
///
/// The session read is deliberately not awaited into the gesture: the spinner
/// belongs to the screen's own data, and holding it open for a second request
/// the user did not ask for makes every refresh feel slower. A role change swaps
/// the shell out from under the screen a moment later, which is the point.
///
/// Tolerant of no [AuthCubit] in scope, so a screen can still be pumped
/// standalone in a test without a session.
Future<void> refreshWithSession(
  BuildContext context,
  Future<void> Function() reload,
) {
  try {
    context.read<AuthCubit>().refreshUser();
  } on ProviderNotFoundException {
    // No session in this tree. Nothing to revalidate.
  }
  return reload();
}
