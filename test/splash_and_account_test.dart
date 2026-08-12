import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/auth/login_screen.dart';
import 'package:practice/features/auth/presentation/account_panel.dart';
import 'package:practice/features/welcome/presentation/welcome_screen.dart';
import 'package:practice/main.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_auth_repository.dart';

void main() {
  group('splash', () {
    testWidgets('offers no buttons — the app decides where to go', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pump(const Duration(seconds: 2));

      // Both used to lead to the same screen, which is a choice not worth
      // asking for.
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Login to your account'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      // The branding is still the point of it.
      expect(find.text('Heritage in Every Bite'), findsOne);
    });

    testWidgets('holds for two seconds, then shows sign-in when signed out', (
      tester,
    ) async {
      // Nothing stored, so restore settles immediately as signed out — which
      // is the case the splash has to hand over to sign-in.
      final cubit = AuthCubit(
        repository: FakeAuthRepository()..storedSession = false,
      );
      await cubit.restore();

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(theme: AppTheme.light, home: const AppRoot()),
        ),
      );
      await tester.pump();

      expect(find.byType(WelcomeScreen), findsOne);
      expect(find.byType(LoginScreen), findsNothing);

      // Still on the splash a hair before the deadline: the floor is what stops
      // a fast restore flashing the splash for one frame.
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byType(WelcomeScreen), findsOne);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOne);
      // Sign-in is the root, so there is no back arrow to a splash that is not
      // somewhere to return to.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('waits for a slow restore rather than flashing sign-in', (
      tester,
    ) async {
      // Signed in, but `hasRestored` is still false — startup has not answered
      // yet. Handing over now would show sign-in to someone already signed in.
      final cubit = AuthCubit(initialUser: AuthFixtures.customer);

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(theme: AppTheme.light, home: const AppRoot()),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(WelcomeScreen), findsOne);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });

  group('restore settles either way', () {
    test('a device with no stored session still finishes startup', () async {
      // Nothing is stored, so no request is made — but the splash is waiting on
      // this flag, and leaving it false would hold the app there for ever.
      final repository = FakeAuthRepository()..storedSession = false;
      final cubit = AuthCubit(repository: repository);

      expect(cubit.state.hasRestored, isFalse);
      await cubit.restore();
      expect(cubit.state.hasRestored, isTrue);
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('a failed restore finishes too, signed out', () async {
      final repository = FakeAuthRepository()
        ..storedSession = true
        ..failure = ApiFailure.offline;
      final cubit = AuthCubit(repository: repository);

      await cubit.restore();

      expect(cubit.state.hasRestored, isTrue);
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('signing out keeps startup settled', () async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.restore();
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      await cubit.signOut();

      // Otherwise the splash would reappear behind the sign-in screen.
      expect(cubit.state.hasRestored, isTrue);
      expect(repository.logoutCalls, 1);
    });
  });

  group('delete account', () {
    test('sends the password and clears the session', () async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      final error = await cubit.deleteAccount('password1');

      expect(error, isNull);
      // The confirmation has to reach the server; a local prompt alone would be
      // theatre.
      expect(repository.deletedWithPassword, 'password1');
      expect(cubit.state.isSignedIn, isFalse);
    });

    test('a refused delete leaves the user signed in', () async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      repository.failure = const ApiFailure(
        kind: ApiFailureKind.unauthorised,
        message: 'That password is not right.',
      );
      final error = await cubit.deleteAccount('wrong');

      expect(error, 'That password is not right.');
      // Signing them out of an account that still exists would tell them it was
      // gone when it is not.
      expect(cubit.state.isSignedIn, isTrue);
    });

    testWidgets('asks for the password before closing the account', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AccountPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOne);
      expect(find.text('Confirm your password'), findsOne);
      expect(find.text('Keep my account'), findsOne);

      // Backing out must not have called anything.
      await tester.tap(find.text('Keep my account'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, 0);
      expect(cubit.state.isSignedIn, isTrue);
    });

    testWidgets('sign out is still one tap', (tester) async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AccountPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(cubit.state.isSignedIn, isFalse);
      expect(repository.logoutCalls, 1);
    });
  });

  group('change password', () {
    test('sends both passwords', () async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);

      final error = await cubit.changePassword(
        currentPassword: 'oldpass123',
        newPassword: 'newpass123',
      );

      expect(error, isNull);
      expect(repository.changedFrom, 'oldpass123');
      expect(repository.changedTo, 'newpass123');
    });

    testWidgets('will not accept the current password as the new one', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      final cubit = AuthCubit(repository: repository);
      await cubit.signIn(email: 'a@b.com', password: 'password1');

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AccountPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'samepass123');
      await tester.enterText(find.byType(TextField).last, 'samepass123');
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();

      // "Changed" for a password that did not change is a confusing success.
      expect(find.text('That is your current password.'), findsOne);
      expect(repository.changedTo, isNull);
    });
  });
}
