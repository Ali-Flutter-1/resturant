import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/admin/domain/admin_user.dart';
import 'package:practice/features/admin/domain/admin_user_repository.dart';
import 'package:practice/features/admin/presentation/admin_users_cubit.dart';
import 'package:practice/features/admin/presentation/admin_users_screen.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/auth/auth_cubit.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_admin_user_repository.dart';

/// Managing accounts.
///
/// The expensive mistakes here are all about trust rather than layout: a role
/// changed optimistically that the server then refused, an admin demoting
/// themselves, or a closed account still offering buttons. Each has a test.
void main() {
  late FakeAdminUserRepository repository;

  setUp(() {
    repository = FakeAdminUserRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget wrap({AuthUser user = AuthFixtures.admin}) => BlocProvider(
    create: (_) => AuthFixtures.cubit(user),
    child: RepositoryProvider<AdminUserRepository>.value(
      value: repository,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const AdminUsersScreen(),
      ),
    ),
  );

  group('the account model', () {
    test('closed wins over deactivated', () {
      // A closed account is also inactive, so the order of these checks decides
      // which badge a row shows. Closed is the one that matters.
      final closed = AdminUser(
        id: 'x',
        firstName: 'Deleted',
        lastName: 'User',
        email: 'x@example.invalid',
        role: UserRole.customer,
        isActive: false,
        isDeleted: true,
      );
      expect(closed.state, AccountState.closed);
      expect(closed.isEditable, isFalse);
    });

    test('an unmodelled role is printed rather than mislabelled', () {
      // `UserRole.fromApi` folds anything unfamiliar into `customer`. On a list
      // of accounts, showing a new backend role as "Customer" would be a lie
      // that an admin could act on.
      final user = AdminUser.fromJson(const {
        'id': 'x',
        'first_name': 'Rey',
        'last_name': 'Manager',
        'email': 'rey@example.com',
        'role': 'kitchen_manager',
        'is_active': true,
      });
      expect(user.role, UserRole.customer);
      expect(user.roleLabel, 'kitchen_manager');
    });

    test('a missing is_active is read as active', () {
      // The API sends it, but a partial payload defaulting to "deactivated"
      // would show every account as locked out.
      final user = AdminUser.fromJson(const {'id': 'x', 'role': 'staff'});
      expect(user.isActive, isTrue);
      expect(user.state, AccountState.active);
    });

    test('the codes that mean the local row is stale', () {
      expect(UserErrorCodes.meansReload(UserErrorCodes.userDeleted), isTrue);
      expect(UserErrorCodes.meansReload(UserErrorCodes.notFound), isTrue);
      // Not stale: the row is right and the move was simply refused.
      expect(
        UserErrorCodes.meansReload(UserErrorCodes.lastActiveAdmin),
        isFalse,
      );
      expect(UserErrorCodes.meansReload(null), isFalse);
    });
  });

  group('the cubit', () {
    test('loads accounts and counters together', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();

      expect(cubit.state.status, UsersStatus.ready);
      expect(cubit.state.users.length, 4);
      expect(cubit.state.stats.admins, 1);
      expect(cubit.state.stats.staff, 1);
      await cubit.close();
    });

    test('closed accounts are hidden until asked for', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      await cubit.closeAccount('u1');
      // Not in the list, because `includeDeleted` is off.
      expect(cubit.state.users.any((u) => u.id == 'u1'), isFalse);

      await cubit.showClosed(true);
      final reappeared = cubit.state.users.firstWhere((u) => u.id == 'u1');
      expect(reappeared.state, AccountState.closed);
      expect(reappeared.email, isNot('ali@example.com'));
      await cubit.close();
    });

    test('a role change adopts what the server returned', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();

      final error = await cubit.update('u1', role: UserRole.staff);
      expect(error, isNull);
      expect(repository.lastUpdate, {
        'id': 'u1',
        'role': UserRole.staff,
        'is_active': null,
      });
      expect(
        cubit.state.users.firstWhere((u) => u.id == 'u1').role,
        UserRole.staff,
      );
      await cubit.close();
    });

    test('a refused change leaves the row alone', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      // The server's own guard: demoting the only admin would lock everybody
      // out of the venue.
      repository.writeFailure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'Cannot remove the last active administrator.',
        code: UserErrorCodes.lastActiveAdmin,
      );

      final error = await cubit.update('u3', role: UserRole.staff);
      expect(error, 'Cannot remove the last active administrator.');
      // Still an admin locally, because nothing was assumed.
      expect(
        cubit.state.users.firstWhere((u) => u.id == 'u3').role,
        UserRole.admin,
      );
      expect(cubit.state.busyIds, isEmpty);
      await cubit.close();
    });

    test('a stale row is re-read when the API says it is gone', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      final before = repository.listCalls;
      repository.writeFailure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'That account is closed.',
        code: UserErrorCodes.userDeleted,
      );

      await cubit.update('u1', isActive: false);
      // Re-read by id, not a whole reload — one row is stale, not the screen.
      expect(repository.listCalls, before);
      await cubit.close();
    });

    test('counters are refreshed after a write', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      final before = repository.statsCalls;

      await cubit.update('u1', role: UserRole.staff);
      expect(repository.statsCalls, before + 1);
      expect(cubit.state.stats.staff, 2);
      await cubit.close();
    });

    test('a filter change goes back to page one', () async {
      repository = FakeAdminUserRepository(pageSize: 2);
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      expect(cubit.state.users.length, 2);
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      expect(cubit.state.users.length, 4);
      expect(cubit.state.hasMore, isFalse);

      // Filtering must not keep page two of the old query on top of page one of
      // the new one.
      await cubit.filterByRole(UserRole.customer);
      expect(cubit.state.page, 1);
      expect(cubit.state.users.every((u) => u.role == UserRole.customer), true);
      await cubit.close();
    });

    test('the filters are one choice, not several toggles', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();

      await cubit.setFilter(isActive: false);
      expect(cubit.state.isActive, isFalse);
      expect(cubit.state.role, isNull);

      // Picking a role clears the state filter rather than combining with it —
      // two chips lit at once gave no way to tell what was in force.
      final before = repository.listCalls;
      await cubit.setFilter(role: UserRole.staff);
      expect(cubit.state.role, UserRole.staff);
      expect(cubit.state.isActive, isNull);
      // And one request per tap. Setting the two dimensions separately fired
      // two, with a state in between that matched neither chip.
      expect(repository.listCalls, before + 1);

      await cubit.setFilter();
      expect(cubit.state.hasFilters, isFalse);
      await cubit.close();
    });

    test('re-picking the filter already in force asks for nothing', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      final before = repository.listCalls;

      await cubit.setFilter(role: UserRole.staff);
      await cubit.setFilter(role: UserRole.staff);
      expect(repository.listCalls, before + 1);
      await cubit.close();
    });

    test('a failed extra page keeps the rows already shown', () async {
      repository = FakeAdminUserRepository(pageSize: 2);
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      repository.failure = const ApiFailure(
        kind: ApiFailureKind.unreachable,
        message: 'No connection.',
      );

      await cubit.loadMore();
      expect(cubit.state.users.length, 2);
      expect(cubit.state.loadingMore, isFalse);
      await cubit.close();
    });

    test('search is debounced and only the last query is asked for', () async {
      final cubit = AdminUsersCubit(repository: repository);
      await cubit.load();
      final before = repository.listCalls;

      cubit.search('p');
      cubit.search('pr');
      cubit.search('priya');
      // Nothing has gone out yet.
      expect(repository.listCalls, before);

      await Future<void>.delayed(const Duration(milliseconds: 420));
      expect(repository.listCalls, before + 1);
      expect(repository.listQueries.last['search'], 'priya');
      expect(cubit.state.users.single.email, 'priya@example.com');
      await cubit.close();
    });

    test('a slow earlier reply cannot overwrite a newer one', () async {
      repository = FakeAdminUserRepository(
        delay: const Duration(milliseconds: 40),
      );
      final cubit = AdminUsersCubit(repository: repository);
      // Two loads in flight; the first must be discarded when it lands.
      final first = cubit.load();
      final second = cubit.filterByRole(UserRole.staff);
      await Future.wait([first, second]);

      expect(cubit.state.role, UserRole.staff);
      expect(cubit.state.users.single.email, 'priya@example.com');
      await cubit.close();
    });
  });

  group('the screen', () {
    testWidgets('lists accounts with role and state badges', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Ali Hassan'), findsOneWidget);
      // The badges are the app's status chips, which upper-case their label.
      expect(find.text('STAFF'), findsWidgets);
      expect(find.text('ADMIN'), findsWidgets);
      // Sam is deactivated, so the row says so.
      expect(find.text('DEACTIVATED'), findsWidgets);
    });

    testWidgets('the signed-in admin is marked and cannot be changed', (
      tester,
    ) async {
      repository = FakeAdminUserRepository(
        users: [
          AdminUser(
            id: AuthFixtures.admin.id,
            firstName: 'Test',
            lastName: 'Admin',
            email: AuthFixtures.admin.email,
            role: UserRole.admin,
            isActive: true,
            isDeleted: false,
          ),
        ],
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('You'), findsOneWidget);

      await tester.tap(find.text('Test Admin'));
      await tester.pumpAndSettle();
      // No role chips and no destructive buttons — the API refuses self-edits,
      // so offering them would only produce a failure.
      expect(find.textContaining('This is your own account'), findsOneWidget);
      expect(find.text('Deactivate'), findsNothing);
      expect(find.text('Close account'), findsNothing);
    });

    testWidgets('a closed account offers no actions', (tester) async {
      repository = FakeAdminUserRepository(
        users: [
          AdminUser(
            id: 'z1',
            firstName: 'Deleted',
            lastName: 'User',
            email: 'deleted@example.invalid',
            role: UserRole.customer,
            isActive: false,
            isDeleted: true,
          ),
        ],
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Hidden by default; the toggle is what brings it in. It sits at the end
      // of the horizontal filter strip, so it has to be scrolled to first.
      expect(find.text('Deleted User'), findsNothing);
      // Wide enough that the whole filter strip is on screen — the toggle is at
      // the end of it, and scrolling a chip row is not what this test is about.
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1000, 2400);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include closed'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deleted User'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be changed'), findsOneWidget);
      expect(find.text('Close account'), findsNothing);
    });

    testWidgets('granting admin access is confirmed first', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('an administrator?'), findsOneWidget);
      await tester.tap(find.text('Leave it'));
      await tester.pumpAndSettle();
      // Backed out, so nothing was sent.
      expect(repository.lastUpdate, isNull);
    });

    testWidgets('closing an account needs a confirmation', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close account'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be reversed'), findsOneWidget);
      await tester.tap(find.text('Close account').last);
      await tester.pumpAndSettle();

      expect(repository.lastClosed, 'u1');
    });

    testWidgets('a failure offers a retry', (tester) async {
      repository.failure = const ApiFailure(
        kind: ApiFailureKind.unreachable,
        message: 'No connection.',
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('No connection'), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.textContaining('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Ali Hassan'), findsOneWidget);
    });
  });
}
