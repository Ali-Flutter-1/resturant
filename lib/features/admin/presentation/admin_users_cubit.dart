import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/page_data.dart';
import '../../auth/domain/auth_user.dart';
import '../domain/admin_user.dart';
import '../domain/admin_user_repository.dart';

enum UsersStatus { loading, ready, failure }

class AdminUsersState extends Equatable {
  const AdminUsersState({
    this.status = UsersStatus.loading,
    this.users = const [],
    this.stats = const UserStats(),
    this.failure,
    this.search = '',
    this.role,
    this.isActive,
    this.includeDeleted = false,
    this.page = 1,
    this.totalPages = 0,
    this.total = 0,
    this.loadingMore = false,
    this.busyIds = const {},
  });

  final UsersStatus status;

  /// Accumulated across pages, newest first.
  final List<AdminUser> users;

  final UserStats stats;
  final ApiFailure? failure;

  final String search;
  final UserRole? role;

  /// Null means either.
  final bool? isActive;

  final bool includeDeleted;

  final int page;
  final int totalPages;
  final int total;

  /// True while a further page is being fetched, so the spinner sits at the
  /// bottom of the list rather than replacing it.
  final bool loadingMore;

  /// Accounts with a write in flight, so only that row is disabled.
  final Set<String> busyIds;

  bool get hasMore => page < totalPages;

  bool get hasFilters =>
      search.trim().isNotEmpty ||
      role != null ||
      isActive != null ||
      includeDeleted;

  AdminUsersState copyWith({
    UsersStatus? status,
    List<AdminUser>? users,
    UserStats? stats,
    ApiFailure? failure,
    String? search,
    UserRole? role,
    bool? isActive,
    bool? includeDeleted,
    int? page,
    int? totalPages,
    int? total,
    bool? loadingMore,
    Set<String>? busyIds,
    bool clearFailure = false,
    bool clearRole = false,
    bool clearActive = false,
  }) {
    return AdminUsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      stats: stats ?? this.stats,
      failure: clearFailure ? null : (failure ?? this.failure),
      search: search ?? this.search,
      role: clearRole ? null : (role ?? this.role),
      isActive: clearActive ? null : (isActive ?? this.isActive),
      includeDeleted: includeDeleted ?? this.includeDeleted,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    users,
    stats,
    failure,
    search,
    role,
    isActive,
    includeDeleted,
    page,
    totalPages,
    total,
    loadingMore,
    busyIds,
  ];
}

/// Accounts, for an administrator.
///
/// Three rules from the guide shape this:
///
///  * **Never update a role optimistically.** Another admin may be changing the
///    same account, and the backend refuses moves this app cannot predict — the
///    last active admin cannot be demoted, and nobody can edit themselves. So the
///    row adopts what the server returned.
///  * **Reset to page 1 whenever a filter changes**, or page 2 of the old query
///    lands on top of page 1 of the new one.
///  * **Refresh the counters after every mutation**, since each one moves them.
class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit({required AdminUserRepository repository})
    : _repository = repository,
      super(const AdminUsersState());

  final AdminUserRepository _repository;

  Timer? _debounce;

  /// Rises with every list request, so a slow earlier one cannot overwrite a
  /// newer answer. The guide asks for the older request to be cancelled; HTTP
  /// gives no cancel here, so the reply is discarded instead — same outcome.
  int _requestId = 0;

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> load({bool silent = false}) async {
    final id = ++_requestId;
    if (!silent) {
      emit(state.copyWith(status: UsersStatus.loading, clearFailure: true));
    }

    try {
      final results = await Future.wait([
        _repository.users(
          page: 1,
          search: state.search,
          role: state.role,
          isActive: state.isActive,
          includeDeleted: state.includeDeleted,
        ),
        _repository.stats(),
      ]);
      if (id != _requestId) return;

      final data = results[0] as PageData<AdminUser>;
      emit(
        state.copyWith(
          status: UsersStatus.ready,
          users: data.items,
          page: data.page,
          totalPages: data.totalPages,
          total: data.total,
          stats: results[1] as UserStats,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      if (id != _requestId) return;
      emit(
        state.copyWith(
          status: silent && state.users.isNotEmpty
              ? UsersStatus.ready
              : UsersStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  /// Fetches the next page and appends it.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));
    final id = ++_requestId;

    try {
      final data = await _repository.users(
        page: state.page + 1,
        search: state.search,
        role: state.role,
        isActive: state.isActive,
        includeDeleted: state.includeDeleted,
      );
      if (id != _requestId) return;

      emit(
        state.copyWith(
          users: [...state.users, ...data.items],
          page: data.page,
          totalPages: data.totalPages,
          total: data.total,
          loadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      if (id != _requestId) return;
      // The rows already on screen stay: failing to fetch page three is no
      // reason to take pages one and two away.
      emit(state.copyWith(loadingMore: false, failure: failure));
    }
  }

  /// Searches, after a pause.
  ///
  /// Debounced by 350ms: a request per keystroke would be a dozen for one name,
  /// and the last one is the only answer anybody wants.
  void search(String query) {
    emit(state.copyWith(search: query));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!isClosed) load(silent: state.users.isNotEmpty);
    });
  }

  /// Sets the role and active filters together.
  ///
  /// One call rather than two, because the two are one choice on screen: a strip
  /// where picking "Admins" clears "Deactivated". Setting them separately meant
  /// two requests for one tap and, in between, a state that matched neither
  /// filter — which is what made several chips look selected at once.
  Future<void> setFilter({UserRole? role, bool? isActive}) async {
    if (role == state.role && isActive == state.isActive) return;
    emit(
      state.copyWith(
        role: role,
        isActive: isActive,
        clearRole: role == null,
        clearActive: isActive == null,
      ),
    );
    await load(silent: state.users.isNotEmpty);
  }

  Future<void> filterByRole(UserRole? role) =>
      setFilter(role: role, isActive: null);

  Future<void> filterByActive(bool? isActive) =>
      setFilter(role: null, isActive: isActive);

  Future<void> showClosed(bool include) async {
    emit(state.copyWith(includeDeleted: include));
    await load(silent: state.users.isNotEmpty);
  }

  /// Changes a role, an active flag, or both.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> update(String id, {UserRole? role, bool? isActive}) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      final updated = await _repository.update(
        id,
        role: role,
        isActive: isActive,
      );
      _adopt(updated);
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      await _refreshStats();
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      // The account is closed or gone, so this screen is the stale one.
      if (UserErrorCodes.meansReload(failure.code)) await refreshOne(id);
      return failure.message;
    }
  }

  /// Closes an account for good.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> closeAccount(String id) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      final closed = await _repository.closeAccount(id);
      if (state.includeDeleted) {
        // The anonymised record replaces the row — the database keeps it for
        // accounting, so it has not gone anywhere.
        _adopt(closed);
      } else {
        emit(
          state.copyWith(
            users: [
              for (final user in state.users)
                if (user.id != id) user,
            ],
          ),
        );
      }
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      await _refreshStats();
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      if (UserErrorCodes.meansReload(failure.code)) await refreshOne(id);
      return failure.message;
    }
  }

  Future<AdminUser?> refreshOne(String id) async {
    try {
      final user = await _repository.userById(id);
      _adopt(user);
      return user;
    } on ApiFailure {
      return null;
    }
  }

  void _adopt(AdminUser user) => emit(
    state.copyWith(
      users: [
        for (final existing in state.users)
          if (existing.id == user.id) user else existing,
      ],
    ),
  );

  Future<void> _refreshStats() async {
    try {
      emit(state.copyWith(stats: await _repository.stats()));
    } on ApiFailure {
      // Counters a moment stale are not worth an error on a screen whose main
      // job just succeeded.
    }
  }
}
