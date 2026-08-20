import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/page_data.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';

enum InboxStatus { loading, ready, failure }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = InboxStatus.loading,
    this.items = const [],
    this.unread = 0,
    this.failure,
    this.page = 1,
    this.totalPages = 0,
    this.loadingMore = false,
  });

  final InboxStatus status;
  final List<AppNotification> items;

  /// The badge. Read from the server rather than counted locally — another
  /// device may have read some, and this list is only the first page.
  final int unread;

  final ApiFailure? failure;
  final int page;
  final int totalPages;
  final bool loadingMore;

  bool get hasMore => page < totalPages;
  bool get hasUnread => unread > 0;

  NotificationsState copyWith({
    InboxStatus? status,
    List<AppNotification>? items,
    int? unread,
    ApiFailure? failure,
    int? page,
    int? totalPages,
    bool? loadingMore,
    bool clearFailure = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      items: items ?? this.items,
      unread: unread ?? this.unread,
      failure: clearFailure ? null : (failure ?? this.failure),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    unread,
    failure,
    page,
    totalPages,
    loadingMore,
  ];
}

/// The in-app inbox and the badge.
///
/// This is the *reliable* half of notifications. A push can be delayed by the
/// OS, dismissed before it is read, or never delivered at all — this list is the
/// durable record, so the badge counts from here and not from what the tray
/// happens to be showing.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({required NotificationRepository repository})
    : _repository = repository,
      super(const NotificationsState());

  final NotificationRepository _repository;

  /// Never unbounded. The API caps a page at 100 and the guide asks for
  /// pagination rather than "give me everything".
  /// Fifteen a page: enough to fill any phone screen with a little to scroll
  /// into, small enough that the first page lands quickly on a slow connection.
  static const int pageSize = 15;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: InboxStatus.loading, clearFailure: true));
    }

    try {
      final results = await Future.wait<Object>([
        _repository.inbox(page: 1, pageSize: pageSize),
        _repository.unreadCount(),
      ]);
      final page = results[0] as PageData<AppNotification>;

      emit(
        state.copyWith(
          status: InboxStatus.ready,
          items: page.items,
          page: page.page,
          totalPages: page.totalPages,
          unread: results[1] as int,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.items.isNotEmpty
              ? InboxStatus.ready
              : InboxStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  /// Just the badge. Cheap enough for startup and after a foreground push.
  Future<void> refreshBadge() async {
    try {
      emit(state.copyWith(unread: await _repository.unreadCount()));
    } on ApiFailure {
      // A stale badge is not worth an error on whatever screen is showing.
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));

    try {
      final next = await _repository.inbox(
        page: state.page + 1,
        pageSize: pageSize,
      );
      emit(
        state.copyWith(
          items: [...state.items, ...next.items],
          page: next.page,
          totalPages: next.totalPages,
          loadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      // The rows already on screen stay.
      emit(state.copyWith(loadingMore: false, failure: failure));
    }
  }

  /// Marks one read, when the user opens it.
  Future<void> markRead(AppNotification notification) async {
    if (!notification.isUnread) return;

    // Optimistic, unlike everything else in this app. The cost of being wrong is
    // a dot that reappears on the next refresh; the cost of waiting is a row
    // that stays bold for a round trip after being tapped.
    emit(
      state.copyWith(
        items: [
          for (final item in state.items)
            if (item.id == notification.id)
              item.markRead(DateTime.now())
            else
              item,
        ],
        unread: state.unread > 0 ? state.unread - 1 : 0,
      ),
    );

    try {
      await _repository.markRead(notification.id);
    } on ApiFailure {
      // Put it back. NOTIFICATION_NOT_FOUND is also how the API answers for
      // somebody else's notification, so this is not always a lost race.
      await load(silent: true);
    }
  }

  /// Drops everything on sign-out.
  ///
  /// The inbox and the badge belong to one account. Leaving them in place means
  /// the next person to sign in on this phone sees the previous user's unread
  /// count until the first refresh lands — briefly, but it is their data.
  void clear() => emit(const NotificationsState(status: InboxStatus.ready));

  Future<void> markAllRead() async {
    if (!state.hasUnread) return;
    final now = DateTime.now();

    emit(
      state.copyWith(
        items: [for (final item in state.items) item.markRead(now)],
        unread: 0,
      ),
    );

    try {
      await _repository.markAllRead();
    } on ApiFailure {
      await load(silent: true);
    }
  }
}
