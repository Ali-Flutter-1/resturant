import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/auth/forgot_password_flow.dart';

import 'support/fake_auth_repository.dart';

/// The three-step reset: email, six-digit code, new password.
///
/// The interesting cases are the branches the API guide calls out as
/// surprising — a lockout that refuses even the correct code, and a wrong email
/// that is indistinguishable from a wrong code.
void main() {
  late FakeAuthRepository repository;
  late AuthCubit cubit;
  var finished = false;

  setUp(() {
    repository = FakeAuthRepository();
    cubit = AuthCubit(repository: repository);
    finished = false;

    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 1400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget wrap({String? email}) => BlocProvider.value(
    value: cubit,
    child: MaterialApp(
      theme: AppTheme.light,
      home: ForgotPasswordFlow(email: email, onFinished: () => finished = true),
    ),
  );

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  /// Explicit pumps rather than `pumpAndSettle` from here on.
  ///
  /// The resend cooldown ticks once a second for a minute, so the tree never
  /// goes idle while it is running and `pumpAndSettle` would wait for ever. That
  /// is a fact about a live countdown, not a fault.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> reachCodeStep(WidgetTester tester) async {
    await tester.pumpWidget(wrap(email: 'ali@example.com'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Send code'));
    await settle(tester);
  }

  Future<void> reachPasswordStep(WidgetTester tester) async {
    await reachCodeStep(tester);
    await tester.enterText(field('000000'), '482913');
    await tester.tap(find.text('Verify code'));
    await settle(tester);
  }

  group('step 1 — email', () {
    testWidgets('asks for the email and prefills it from sign-in', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(email: 'ali@example.com'));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('What is your email?'), findsOne);
      expect(find.widgetWithText(TextField, 'ali@example.com'), findsOne);
    });

    testWidgets('refuses an incomplete address without sending', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(email: 'nope'));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text('That email address looks incomplete.'), findsOne);
      // One of five hourly codes must not be spent on a typo.
      expect(repository.forgotEmail, isNull);
    });

    testWidgets('moves to the code step on success', (tester) async {
      await reachCodeStep(tester);

      expect(repository.forgotEmail, 'ali@example.com');
      expect(find.text('Enter your code'), findsOne);
      // The address is repeated, because a typo in it is the likeliest reason no
      // email arrives — and the API refuses a wrong email identically to a wrong
      // code, so the app cannot tell them apart.
      expect(find.textContaining('ali@example.com'), findsWidgets);
    });
  });

  group('step 2 — code', () {
    testWidgets('will not send fewer than six digits', (tester) async {
      await reachCodeStep(tester);

      await tester.enterText(field('000000'), '4829');
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      expect(find.text('Enter the six digits from the email.'), findsOne);
      expect(repository.verifyCalls, 0);
    });

    testWidgets('strips the space in a pasted code', (tester) async {
      await reachCodeStep(tester);

      await tester.enterText(field('000000'), '482 913');
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      // A code copied out of an email arrives with the space in it, and that is
      // the app's problem to solve rather than the user's.
      expect(repository.verifiedCode, '482913');
    });

    testWidgets('a wrong code keeps the user here with the API message', (
      tester,
    ) async {
      await reachCodeStep(tester);

      repository.verifyFailure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: "That code isn't right. You have 3 tries left.",
        code: ResetErrorCodes.codeInvalid,
      );
      await tester.enterText(field('000000'), '111111');
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      // The message carries the remaining tries, so it is shown verbatim.
      expect(
        find.text("That code isn't right. You have 3 tries left."),
        findsOne,
      );
      expect(find.text('Enter your code'), findsOne);
    });

    testWidgets('a lockout sends the user back to the start', (tester) async {
      await reachCodeStep(tester);

      repository.verifyFailure = const ApiFailure(
        kind: ApiFailureKind.tooManyRequests,
        message: 'Too many attempts. Ask for a new code.',
        code: ResetErrorCodes.tooManyAttempts,
      );
      await tester.enterText(field('000000'), '111111');
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      // After the lockout even the correct code is refused, so staying here
      // would be a screen that cannot succeed.
      expect(find.text('What is your email?'), findsOne);
      expect(find.text('Too many attempts. Ask for a new code.'), findsOne);
    });

    testWidgets('an expired code sends the user back to the start', (
      tester,
    ) async {
      await reachCodeStep(tester);

      repository.verifyFailure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'That code has expired.',
        code: ResetErrorCodes.codeExpired,
      );
      await tester.enterText(field('000000'), '482913');
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      expect(find.text('What is your email?'), findsOne);
    });

    testWidgets('resend is held for a minute', (tester) async {
      await reachCodeStep(tester);

      // The API silently caps requests at five an hour and the sixth sends
      // nothing, so burning the allowance in ten taps must not be possible.
      expect(find.textContaining('Resend code in'), findsOne);
      final held = tester.widget<TextButton>(
        find.ancestor(
          of: find.textContaining('Resend code in'),
          matching: find.byType(TextButton),
        ),
      );
      expect(held.onPressed, isNull);

      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Resend code'), findsOne);

      await tester.tap(find.text('Resend code'));
      await settle(tester);
      expect(find.text('A new code is on its way.'), findsOne);
    });
  });

  group('step 3 — new password', () {
    testWidgets('reached with a token, and mirrors the password rules', (
      tester,
    ) async {
      await reachPasswordStep(tester);

      expect(find.text('Choose a new password'), findsOne);

      await tester.enterText(field('At least 8 characters'), 'short');
      await tester.tap(find.text('Set new password'));
      await settle(tester);

      expect(find.text('Use at least 8 characters.'), findsOne);
      expect(repository.resetCalls, 0);
    });

    testWidgets('sends the reset token, never the six-digit code', (
      tester,
    ) async {
      await reachPasswordStep(tester);

      await tester.enterText(field('At least 8 characters'), 'Br4ndNew2');
      await tester.tap(find.text('Set new password'));
      await settle(tester);

      // The code is only ever a step-2 credential; sending it here is refused.
      expect(repository.resetToken, 'reset-token-abc');
      expect(repository.resetNewPassword, 'Br4ndNew2');
      expect(finished, isTrue);
    });

    testWidgets('clears this device\'s session and does not sign in', (
      tester,
    ) async {
      await reachPasswordStep(tester);

      await tester.enterText(field('At least 8 characters'), 'Br4ndNew2');
      await tester.tap(find.text('Set new password'));
      await settle(tester);

      // The reset revokes every session including this one, so the stored
      // tokens are worthless and are dropped rather than left to fail later.
      expect(repository.forgetCalls, 1);
      expect(cubit.state.isSignedIn, isFalse);
    });

    testWidgets('a weak password refused by the server keeps the token', (
      tester,
    ) async {
      await reachPasswordStep(tester);

      repository.failure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'Please check the highlighted fields and try again.',
        code: ResetErrorCodes.validationFailed,
        fieldErrors: {'new_password': 'That password is too common.'},
      );
      await tester.enterText(field('At least 8 characters'), 'Passw0rd1');
      await tester.tap(find.text('Set new password'));
      await settle(tester);

      // The token survives a 422, so the user stays here rather than starting
      // the whole flow again over a password choice.
      expect(find.text('Choose a new password'), findsOne);
      expect(find.text('That password is too common.'), findsOne);
    });

    testWidgets('an invalid token sends the user back to the start', (
      tester,
    ) async {
      await reachPasswordStep(tester);

      repository.failure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'That reset link has already been used.',
        code: ResetErrorCodes.tokenInvalid,
      );
      await tester.enterText(field('At least 8 characters'), 'Br4ndNew2');
      await tester.tap(find.text('Set new password'));
      await settle(tester);

      expect(find.text('What is your email?'), findsOne);
      expect(finished, isFalse);
    });
  });

  group('PasswordResetSession', () {
    test('turns expires_in into a deadline', () {
      final session = PasswordResetSession.fromJson({
        'reset_token': 'abc',
        'expires_in': 600,
      });

      expect(session.token, 'abc');
      expect(session.hasExpired, isFalse);
      expect(session.remaining.inMinutes, greaterThanOrEqualTo(9));
    });

    test('an elapsed session reports no time left rather than negative', () {
      final session = PasswordResetSession(
        token: 'abc',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(session.hasExpired, isTrue);
      expect(session.remaining, Duration.zero);
    });

    test('never prints the token', () {
      const session = PasswordResetSession.new;
      final built = session(
        token: 'super-secret',
        expiresAt: DateTime(2026, 8, 12),
      );

      // This object ends up in logs and error reports; the credential must not
      // travel with it.
      expect(built.toString(), isNot(contains('super-secret')));
    });
  });

  group('ResetErrorCodes', () {
    test('knows which failures cannot be retried in place', () {
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.tooManyAttempts),
        isTrue,
      );
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.codeExpired),
        isTrue,
      );
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.tokenInvalid),
        isTrue,
      );
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.tokenExpired),
        isTrue,
      );
      // A wrong code and a weak password are both retried where the user is.
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.codeInvalid),
        isFalse,
      );
      expect(
        ResetErrorCodes.sendsUserBackToStart(ResetErrorCodes.validationFailed),
        isFalse,
      );
      expect(ResetErrorCodes.sendsUserBackToStart(null), isFalse);
    });
  });
}
