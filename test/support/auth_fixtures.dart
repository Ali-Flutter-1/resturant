import 'package:practice/features/auth/auth_cubit.dart';

/// Signed-in users for tests that need a shell rendered, not a sign-in flow.
///
/// These replace the old `AuthCubit.signInAs` backdoor. That method existed only
/// so tests could reach the shells without a server, and shipping it meant the
/// production cubit carried a way to fake a session — with demo buttons on the
/// login screen wired straight to it. Seeding `AuthCubit(initialUser: …)`
/// achieves the same thing through the ordinary constructor.
abstract final class AuthFixtures {
  static const customer = AuthUser(
    id: 'test-customer',
    email: 'customer@example.com',
    firstName: 'Test',
    lastName: 'Customer',
    role: UserRole.customer,
  );

  static const staff = AuthUser(
    id: 'test-staff',
    email: 'staff@tscafe.co.uk',
    firstName: 'Test',
    lastName: 'Staff',
    role: UserRole.staff,
  );

  static const admin = AuthUser(
    id: 'test-admin',
    email: 'admin@tscafe.co.uk',
    firstName: 'Test',
    lastName: 'Admin',
    role: UserRole.admin,
  );

  /// A cubit already signed in as [user], with no repository — a test that
  /// starts here is not exercising the network.
  static AuthCubit cubit(AuthUser user) => AuthCubit(initialUser: user);
}
