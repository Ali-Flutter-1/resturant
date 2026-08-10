import 'package:equatable/equatable.dart';

/// Who is using the app.
///
/// The API has three roles, not two. `staff` can work the order queue and the
/// booking sheet but cannot manage the floor or other accounts, so it belongs on
/// the admin side of the app with a narrower set of powers — collapsing it into
/// `admin` would hand a waiter the ability to delete tables.
enum UserRole {
  customer,
  staff,
  admin;

  /// Parses the API's `role` string. An unknown role is treated as a customer:
  /// if the server ever adds one, showing the least-privileged interface is the
  /// safe way to be wrong.
  static UserRole fromApi(Object? value) => switch (value) {
    'admin' => UserRole.admin,
    'staff' => UserRole.staff,
    _ => UserRole.customer,
  };

  /// Whether this role sees the staff-facing shell.
  bool get usesAdminShell => this != UserRole.customer;

  /// Whether this role may manage the floor plan, the menu and other accounts.
  /// Staff may not.
  bool get canManageVenue => this == UserRole.admin;
}

/// The signed-in person, as `/auth/me` describes them.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      role: UserRole.fromApi(json['role']),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? avatarUrl;

  /// Falls back to the email when a name is missing, so a greeting never reads
  /// as "Welcome back, ".
  String get displayName {
    final full = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
    return full.isEmpty ? email : full;
  }

  @override
  List<Object?> get props => [id, email, firstName, lastName, role, avatarUrl];
}
