import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/network/page_data.dart';
import 'package:practice/features/admin/domain/admin_user.dart';
import 'package:practice/features/admin/domain/admin_user_repository.dart';
import 'package:practice/features/auth/domain/auth_user.dart';

/// Accounts, in memory.
///
/// Returns copies rather than its own list, for the same reason as the order
/// fake: a shared reference lets a write mutate the list
/// already in cubit state, Equatable then sees no change, and `emit` silently
/// does nothing.
class FakeAdminUserRepository implements AdminUserRepository {
  FakeAdminUserRepository({List<AdminUser>? users, this.delay, this.pageSize})
    : _users = users ?? [...defaults];

  /// Holds the answer, so a test can observe the loading state.
  final Duration? delay;

  /// Overrides the page size the fake actually paginates by, so a small fixture
  /// can still produce more than one page.
  final int? pageSize;

  static final defaults = <AdminUser>[
    AdminUser(
      id: 'u1',
      firstName: 'Ali',
      lastName: 'Hassan',
      email: 'ali@example.com',
      role: UserRole.customer,
      isActive: true,
      isDeleted: false,
      hasPassword: true,
      isEmailVerified: true,
      createdAt: DateTime(2026, 3, 1),
    ),
    AdminUser(
      id: 'u2',
      firstName: 'Priya',
      lastName: 'Raj',
      email: 'priya@example.com',
      role: UserRole.staff,
      isActive: true,
      isDeleted: false,
      hasGoogle: true,
      createdAt: DateTime(2026, 4, 2),
    ),
    AdminUser(
      id: 'u3',
      firstName: 'Tara',
      lastName: 'Owner',
      email: 'tara@example.com',
      role: UserRole.admin,
      isActive: true,
      isDeleted: false,
      hasPassword: true,
      createdAt: DateTime(2026, 1, 3),
    ),
    AdminUser(
      id: 'u4',
      firstName: 'Sam',
      lastName: 'Quiet',
      email: 'sam@example.com',
      role: UserRole.customer,
      isActive: false,
      isDeleted: false,
      hasPassword: true,
      createdAt: DateTime(2026, 5, 4),
    ),
  ];

  List<AdminUser> _users;

  ApiFailure? failure;

  /// Fails only the writes, so a test can load fine and be refused on the change
  /// — which is the interesting case.
  ApiFailure? writeFailure;

  int listCalls = 0;
  int statsCalls = 0;
  final List<Map<String, Object?>> listQueries = [];
  Map<String, Object?>? lastUpdate;
  String? lastClosed;

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<PageData<AdminUser>> users({
    int page = 1,
    int pageSize = 20,
    String? search,
    UserRole? role,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    listCalls++;
    listQueries.add({
      'page': page,
      'search': search,
      'role': role,
      'is_active': isActive,
      'include_deleted': includeDeleted,
    });
    await _wait();
    _check();

    final query = (search ?? '').trim().toLowerCase();
    var rows = List.of(_users);
    if (!includeDeleted) rows = rows.where((u) => !u.isDeleted).toList();
    if (role != null) rows = rows.where((u) => u.role == role).toList();
    if (isActive != null) {
      rows = rows.where((u) => u.isActive == isActive).toList();
    }
    if (query.isNotEmpty) {
      rows = rows
          .where(
            (u) =>
                u.displayName.toLowerCase().contains(query) ||
                u.email.toLowerCase().contains(query),
          )
          .toList();
    }

    final size = this.pageSize ?? pageSize;
    final start = (page - 1) * size;
    final slice = start >= rows.length
        ? const <AdminUser>[]
        : rows.sublist(start, (start + size).clamp(0, rows.length));

    return PageData(
      items: slice,
      page: page,
      pageSize: size,
      total: rows.length,
      totalPages: rows.isEmpty ? 1 : (rows.length + size - 1) ~/ size,
    );
  }

  @override
  Future<UserStats> stats() async {
    statsCalls++;
    await _wait();
    _check();
    final live = _users.where((u) => !u.isDeleted);
    return UserStats(
      total: _users.length,
      active: live.where((u) => u.isActive).length,
      customers: live.where((u) => u.role == UserRole.customer).length,
      staff: live.where((u) => u.role == UserRole.staff).length,
      admins: live.where((u) => u.role == UserRole.admin).length,
      deleted: _users.where((u) => u.isDeleted).length,
    );
  }

  @override
  Future<AdminUser> userById(String id) async {
    await _wait();
    _check();
    return _users.firstWhere((u) => u.id == id);
  }

  @override
  Future<AdminUser> update(String id, {UserRole? role, bool? isActive}) async {
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    lastUpdate = {'id': id, 'role': role, 'is_active': isActive};
    return _replace(
      id,
      (existing) => _copy(existing, role: role, isActive: isActive),
    );
  }

  @override
  Future<AdminUser> closeAccount(String id) async {
    await _wait();
    final error = writeFailure ?? failure;
    if (error != null) throw error;

    lastClosed = id;
    // Anonymised the way the API describes it: the row survives, the person's
    // details do not.
    return _replace(
      id,
      (existing) => AdminUser(
        id: existing.id,
        firstName: 'Deleted',
        lastName: 'User',
        email: 'deleted+${existing.id}@example.invalid',
        role: existing.role,
        isActive: false,
        isDeleted: true,
        createdAt: existing.createdAt,
      ),
    );
  }

  AdminUser _replace(String id, AdminUser Function(AdminUser) change) {
    final updated = change(_users.firstWhere((u) => u.id == id));
    _users = [
      for (final u in _users)
        if (u.id == id) updated else u,
    ];
    return updated;
  }

  static AdminUser _copy(AdminUser from, {UserRole? role, bool? isActive}) =>
      AdminUser(
        id: from.id,
        firstName: from.firstName,
        lastName: from.lastName,
        email: from.email,
        role: role ?? from.role,
        isActive: isActive ?? from.isActive,
        isDeleted: from.isDeleted,
        avatarUrl: from.avatarUrl,
        isEmailVerified: from.isEmailVerified,
        hasPassword: from.hasPassword,
        hasGoogle: from.hasGoogle,
        lastLoginAt: from.lastLoginAt,
        createdAt: from.createdAt,
      );
}
