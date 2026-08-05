import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/auth/login_screen.dart';

void main() {
  group('AuthCubit', () {
    test('starts signed out', () {
      expect(AuthCubit().state.isSignedIn, isFalse);
    });

    test('the customer demo account signs in as a customer', () async {
      final cubit = AuthCubit();
      await cubit.signIn(email: 'customer@tscafe.co.uk', password: 'anything');
      expect(cubit.state.role, UserRole.customer);
      expect(cubit.state.error, isNull);
    });

    test('the admin demo account signs in as an admin', () async {
      final cubit = AuthCubit();
      await cubit.signIn(email: 'admin@tscafe.co.uk', password: 'anything');
      expect(cubit.state.role, UserRole.admin);
    });

    test('email matching ignores case and surrounding space', () async {
      final cubit = AuthCubit();
      await cubit.signIn(email: '  Admin@TsCafe.co.uk ', password: 'x');
      expect(cubit.state.role, UserRole.admin);
    });

    test('an unknown email is rejected and stays signed out', () async {
      final cubit = AuthCubit();
      await cubit.signIn(email: 'nobody@example.com', password: 'x');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.error, isNotNull);
    });

    test('an empty password is rejected', () async {
      final cubit = AuthCubit();
      await cubit.signIn(email: 'admin@tscafe.co.uk', password: '');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.error, isNotNull);
    });

    test('signOut clears the session', () async {
      final cubit = AuthCubit()..signInAs(UserRole.admin);
      expect(cubit.state.isSignedIn, isTrue);
      cubit.signOut();
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.email, isNull);
    });

    test('a failed sign-in does not clear an existing session', () async {
      final cubit = AuthCubit()..signInAs(UserRole.admin);
      await cubit.signIn(email: 'nobody@example.com', password: 'x');
      // The cubit reports the error but must not silently sign the user out.
      expect(cubit.state.role, UserRole.admin);
    });
  });

  group('LoginScreen', () {
    Widget harness(AuthCubit cubit) => BlocProvider.value(
      value: cubit,
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );

    testWidgets('the demo role buttons sign in directly', (tester) async {
      final cubit = AuthCubit();
      await tester.pumpWidget(harness(cubit));
      await tester.pumpAndSettle();

      // The demo panel sits below the fold on a test-sized viewport.
      await tester.ensureVisible(find.text('Admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(cubit.state.role, UserRole.admin);
    });

    testWidgets('a rejected sign-in surfaces its error on screen', (
      tester,
    ) async {
      final cubit = AuthCubit(latency: Duration.zero);
      await tester.pumpWidget(harness(cubit));
      await tester.pumpAndSettle();

      // Driven through the cubit rather than the text field: focusing a
      // TextField leaves a cursor-blink Timer pending at teardown, which the
      // test binding treats as a failure.
      await cubit.signIn(email: 'wrong@example.com', password: 'x');
      await tester.pumpAndSettle();

      expect(find.textContaining('No account for that email'), findsOneWidget);
      expect(cubit.state.isSignedIn, isFalse);

      // flutter_animate schedules its staggered delays on Timers. Tear the
      // tree down and let them expire, or the binding fails the test for a
      // timer that outlived the widget.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
