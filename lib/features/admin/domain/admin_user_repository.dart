import '../../../core/network/page_data.dart';
import '../../auth/domain/auth_user.dart';
import 'admin_user.dart';

/// Managing accounts. Administrators only — staff and customers get a 403.
///
/// Deliberately narrow, because the API is: an admin can change a role and an
/// active flag, and close an account. Names, emails and passwords are somebody
/// else's to change, and there is no route for them.
abstract interface class AdminUserRepository {
  /// Newest first, paginated.
  ///
  /// [search] matches a name or an email. Closed accounts are hidden unless
  /// [includeDeleted].
  Future<PageData<AdminUser>> users({
    int page = 1,
    int pageSize = 20,
    String? search,
    UserRole? role,
    bool? isActive,
    bool includeDeleted = false,
  });

  Future<UserStats> stats();

  Future<AdminUser> userById(String id);

  /// Changes only what is passed.
  ///
  /// Returns the updated account, so the screen shows what the server did rather
  /// than what it hoped for.
  Future<AdminUser> update(String id, {UserRole? role, bool? isActive});

  /// Closes and anonymises an account. Not reversible through the API.
  ///
  /// Returns the anonymised record — the row survives for accounting, so this is
  /// not a deletion and a later fetch by id still answers.
  Future<AdminUser> closeAccount(String id);
}
