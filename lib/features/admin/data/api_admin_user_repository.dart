import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/page_data.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/admin_user.dart';
import '../domain/admin_user_repository.dart';

class ApiAdminUserRepository implements AdminUserRepository {
  ApiAdminUserRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<PageData<AdminUser>> users({
    int page = 1,
    int pageSize = 20,
    String? search,
    UserRole? role,
    bool? isActive,
    bool includeDeleted = false,
  }) async {
    final rows = await _client.page(
      ApiConstants.adminUsers,
      query: {
        'page': page,
        // Capped at the API's maximum rather than trusting the caller.
        'page_size': pageSize.clamp(1, 100),
        // Omitted when blank: an absent filter and a filter for nothing are
        // different requests.
        'search': ?_orNull(search),
        'role': ?role?.name,
        'is_active': ?isActive,
        if (includeDeleted) 'include_deleted': true,
      },
    );

    return PageData(
      items: rows.items.map(AdminUser.fromJson).toList(),
      page: rows.page,
      pageSize: rows.pageSize,
      total: rows.total,
      totalPages: rows.totalPages,
    );
  }

  @override
  Future<UserStats> stats() async =>
      UserStats.fromJson(await _client.object(ApiConstants.adminUserStats));

  @override
  Future<AdminUser> userById(String id) async =>
      AdminUser.fromJson(await _client.object(ApiConstants.adminUser(id)));

  @override
  Future<AdminUser> update(String id, {UserRole? role, bool? isActive}) async {
    final data = await _client.object(
      ApiConstants.adminUser(id),
      method: 'PATCH',
      // Only role and is_active. Names, emails, deleted flags and login-method
      // flags are not part of the update model and would be ignored — sending
      // them would only suggest to a reader that they do something.
      body: {'role': ?role?.name, 'is_active': ?isActive},
    );
    return AdminUser.fromJson(data);
  }

  @override
  Future<AdminUser> closeAccount(String id) async => AdminUser.fromJson(
    await _client.object(ApiConstants.adminUser(id), method: 'DELETE'),
  );

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
