import 'package:equatable/equatable.dart';

import '../../auth/domain/auth_user.dart';

/// What an account's state is, in the three words the guide gives for it.
enum AccountState {
  active('Active'),
  deactivated('Deactivated'),
  closed('Closed');

  const AccountState(this.label);
  final String label;
}

/// One account, as an administrator sees it.
///
/// Note what is absent: no password hash, no Google subject. The API never sends
/// them — [hasPassword] and [hasGoogle] only say which ways in exist — and there
/// is no route for an admin to edit somebody else's name, email or password. Only
/// the role and the active flag can change.
class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isDeleted,
    this.avatarUrl,
    this.isEmailVerified = false,
    this.hasPassword = false,
    this.hasGoogle = false,
    this.lastLoginAt,
    this.createdAt,
    this.rawRole,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id']?.toString() ?? '',
    firstName: json['first_name']?.toString() ?? '',
    lastName: json['last_name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: UserRole.fromApi(json['role']),
    // Kept because the app's `UserRole` folds anything unfamiliar into
    // `customer`. On a customer's own profile that is harmless; in a list of
    // accounts an unrecognised role shown as "Customer" would be a lie, so the
    // original survives and the row prints it — see [roleLabel].
    rawRole: json['role']?.toString(),
    isActive: json['is_active'] != false,
    isDeleted: json['is_deleted'] == true,
    avatarUrl: json['avatar_url']?.toString(),
    isEmailVerified: json['is_email_verified'] == true,
    hasPassword: json['has_password'] == true,
    hasGoogle: json['has_google'] == true,
    lastLoginAt: _date(json['last_login_at']),
    createdAt: _date(json['created_at']),
  );

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? rawRole;
  final bool isActive;
  final bool isDeleted;
  final String? avatarUrl;
  final bool isEmailVerified;

  /// Whether a password sign-in exists. Not the password.
  final bool hasPassword;

  /// Whether a Google identity is linked. Not the identity.
  final bool hasGoogle;

  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  String get displayName {
    final full = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
    return full.isEmpty ? email : full;
  }

  /// The role as it should be shown.
  ///
  /// Prints the API's own word when it is one this app does not model, rather
  /// than mislabelling it.
  String get roleLabel {
    final raw = rawRole?.trim().toLowerCase();
    const known = {'customer', 'staff', 'admin'};
    if (raw != null && raw.isNotEmpty && !known.contains(raw)) return rawRole!;
    return switch (role) {
      UserRole.customer => 'Customer',
      UserRole.staff => 'Staff',
      UserRole.admin => 'Admin',
    };
  }

  /// The three states, in the order the guide defines them: closed wins over
  /// deactivated, because a closed account is also inactive.
  AccountState get state => isDeleted
      ? AccountState.closed
      : isActive
      ? AccountState.active
      : AccountState.deactivated;

  /// Whether anything about this account can be changed.
  ///
  /// A closed account is finished — the API refuses to edit one — so the buttons
  /// are disabled rather than offered and then refused.
  bool get isEditable => !isDeleted;

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    email,
    role,
    rawRole,
    isActive,
    isDeleted,
    avatarUrl,
    isEmailVerified,
    hasPassword,
    hasGoogle,
    lastLoginAt,
    createdAt,
  ];
}

/// The dashboard counters from `/admin/users/stats`.
class UserStats extends Equatable {
  const UserStats({
    this.total = 0,
    this.active = 0,
    this.customers = 0,
    this.staff = 0,
    this.admins = 0,
    this.deleted = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    total: (json['total'] as num?)?.toInt() ?? 0,
    active: (json['active'] as num?)?.toInt() ?? 0,
    customers: (json['customers'] as num?)?.toInt() ?? 0,
    staff: (json['staff'] as num?)?.toInt() ?? 0,
    admins: (json['admins'] as num?)?.toInt() ?? 0,
    deleted: (json['deleted'] as num?)?.toInt() ?? 0,
  );

  /// Every row, closed accounts included.
  final int total;
  final int active;
  final int customers;
  final int staff;
  final int admins;
  final int deleted;

  @override
  List<Object?> get props => [total, active, customers, staff, admins, deleted];
}

/// The API's `error.code` values for this area.
///
/// Branching on the code rather than the message: these are the cases where the
/// app should do something specific rather than only report.
abstract final class UserErrorCodes {
  /// The signed-in admin tried to change their own role or access.
  static const String cannotEditSelf = 'CANNOT_EDIT_SELF';
  static const String cannotDeleteSelf = 'CANNOT_DELETE_SELF';

  /// Would leave the venue with no administrator.
  static const String lastActiveAdmin = 'LAST_ACTIVE_ADMIN';

  /// The account is closed, so nothing about it can change.
  static const String userDeleted = 'USER_DELETED';
  static const String userAlreadyDeleted = 'USER_ALREADY_DELETED';

  static const String notFound = 'USER_NOT_FOUND';
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// Whether this failure means the local row is stale and should be re-read.
  static bool meansReload(String? code) =>
      code == userDeleted || code == userAlreadyDeleted || code == notFound;
}
