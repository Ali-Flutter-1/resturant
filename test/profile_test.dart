import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/auth/presentation/profile_screen.dart';

import 'support/fake_auth_repository.dart';

/// The profile screen, which every role shares.
///
/// Staff and admin previously had no way to reach their own account at all:
/// there was no profile screen in the admin shell, and sign-out lived on the
/// customers' About screen, which that shell never shows.
void main() {
  setUp(() {
    // A tall viewport, because the assertions are about controls near the
    // bottom of the screen — sign out, delete, "Get in touch". On the default
    // 800x600 they sit off-screen and are genuinely not hit-testable, which is
    // a fact about the test window rather than about the screen.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 1600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  ({Widget widget, AuthCubit cubit, FakeAuthRepository repo}) build(
    AuthUser user, {
    VoidCallback? onGetInTouch,
  }) {
    final repo = FakeAuthRepository(user: user);
    final cubit = AuthCubit(repository: repo, initialUser: user);
    return (
      widget: BlocProvider.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(onGetInTouch: onGetInTouch),
        ),
      ),
      cubit: cubit,
      repo: repo,
    );
  }

  const customer = AuthUser(
    id: 'u1',
    email: 'ali@example.com',
    firstName: 'Ali',
    lastName: 'Hassan',
    role: UserRole.customer,
  );

  testWidgets('shows who you are signed in as', (tester) async {
    await tester.pumpWidget(build(customer).widget);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Ali Hassan'), findsWidgets);
    expect(find.text('ali@example.com'), findsWidgets);
    // A role glyph rather than initials: initials read as identity but say
    // nothing about what the account can do.
    expect(find.byIcon(Icons.person), findsWidgets);
  });

  for (final (role, label) in [
    (UserRole.customer, 'Customer'),
    (UserRole.staff, 'Staff'),
    (UserRole.admin, 'Administrator'),
  ]) {
    testWidgets('names the $label role in words', (tester) async {
      final user = AuthUser(
        id: 'u1',
        email: 'x@example.com',
        firstName: 'Sam',
        lastName: 'Owner',
        role: role,
      );
      await tester.pumpWidget(build(user).widget);
      await tester.pump(const Duration(seconds: 2));

      // "admin" on its own tells a person nothing about what they can do.
      expect(find.text(label), findsOne);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('editing the name sends a PATCH and adopts the result', (
    tester,
  ) async {
    final built = build(customer);
    await tester.pumpWidget(built.widget);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Ali'), 'Alia');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(built.repo.updatedFirstName, 'Alia');
    expect(built.repo.updatedLastName, 'Hassan');
    // Adopted from the server's response, so the screen shows what was saved
    // rather than what was typed.
    expect(built.cubit.state.user?.firstName, 'Alia');
    expect(find.text('Your details were updated.'), findsOne);
  });

  testWidgets('a refused edit keeps the sheet open and says why', (
    tester,
  ) async {
    final built = build(customer);
    await tester.pumpWidget(built.widget);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    built.repo.failure = const ApiFailure(
      kind: ApiFailureKind.invalid,
      message: 'That name is not allowed.',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('That name is not allowed.'), findsOne);
    expect(find.text('Save changes'), findsOne);
  });

  testWidgets('will not save an empty name', (tester) async {
    final built = build(customer);
    await tester.pumpWidget(built.widget);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Ali'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOne);
    expect(built.repo.updatedFirstName, isNull);
  });

  testWidgets('the email is shown but not editable', (tester) async {
    await tester.pumpWidget(build(customer).widget);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('ali@example.com'), findsWidgets);

    // The API refuses to change an email here because it needs verification, and
    // the absence of a field says so — no line of instructions needed.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'ali@example.com'), findsNothing);
  });

  testWidgets('offers Get in touch only where the app has it', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      build(customer, onGetInTouch: () => tapped = true).widget,
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Get in touch'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);

    // Absent in the admin app, which has no contact screen.
    await tester.pumpWidget(build(customer).widget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Get in touch'), findsNothing);
  });

  testWidgets('offers pull-to-refresh', (tester) async {
    await tester.pumpWidget(build(customer).widget);
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(RefreshIndicator), findsOne);
  });

  test('refreshing re-reads /auth/me and adopts the new user', () async {
    // At the cubit rather than through the gesture: the gesture is Flutter's,
    // and what matters here is that a refresh picks up a change made elsewhere
    // — a role promoted in the admin panel, a name edited on another device.
    final repo = FakeAuthRepository(user: customer);
    final cubit = AuthCubit(repository: repo, initialUser: customer);

    repo.user = const AuthUser(
      id: 'u1',
      email: 'ali@example.com',
      firstName: 'Ali',
      lastName: 'Hassan',
      role: UserRole.staff,
    );
    await cubit.refreshUser();

    expect(repo.currentUserCalls, 1);
    expect(cubit.state.role, UserRole.staff);
  });

  test(
    'a failed refresh keeps the session that is already on screen',
    () async {
      final repo = FakeAuthRepository(user: customer);
      final cubit = AuthCubit(repository: repo, initialUser: customer);

      repo.failure = ApiFailure.offline;
      await cubit.refreshUser();

      // Quiet on failure: the session on screen is still usable, and an error
      // banner for a refresh nobody asked for would be noise.
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.error, isNull);
    },
  );

  testWidgets('signing out is reachable from here', (tester) async {
    final built = build(customer);
    await tester.pumpWidget(built.widget);
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(built.cubit.state.isSignedIn, isFalse);
    expect(built.repo.logoutCalls, 1);
  });

  group('the avatar marks the role', () {
    testWidgets('a customer is a person, with no badge', (tester) async {
      await tester.pumpWidget(build(customer).widget);
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.person), findsWidgets);
      // On a customer's own profile a badge saying "customer" would be
      // decoration.
      expect(find.byIcon(Icons.shield), findsNothing);
    });

    testWidgets('staff carry the service mark', (tester) async {
      const staff = AuthUser(
        id: 'u2',
        email: 'staff@tscafe.co.uk',
        firstName: 'Sam',
        lastName: 'Server',
        role: UserRole.staff,
      );
      await tester.pumpWidget(build(staff).widget);
      await tester.pump(const Duration(seconds: 2));

      // Twice: the avatar glyph and the badge on its corner.
      expect(find.byIcon(Icons.room_service), findsNWidgets(2));
    });

    testWidgets('an administrator carries the shield', (tester) async {
      const admin = AuthUser(
        id: 'u3',
        email: 'owner@tscafe.co.uk',
        firstName: 'Ada',
        lastName: 'Owner',
        role: UserRole.admin,
      );
      await tester.pumpWidget(build(admin).widget);
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.admin_panel_settings), findsOne);
      expect(find.byIcon(Icons.shield), findsOne);
    });
  });
}
