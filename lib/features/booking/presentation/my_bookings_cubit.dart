import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

enum BookingsStatus { loading, ready, failure }

class MyBookingsState extends Equatable {
  const MyBookingsState({
    this.status = BookingsStatus.loading,
    this.bookings = const [],
    this.detail,
    this.failure,
    this.page = 1,
    this.totalPages = 0,
    this.total = 0,
    this.loadingMore = false,
    this.busy = false,
  });

  final BookingsStatus status;
  final List<ReservationSummary> bookings;

  /// The booking currently open, in full. Summaries carry no contact details,
  /// reason or `can_cancel`, so a detail screen has to fetch.
  final ReservationDetail? detail;

  final ApiFailure? failure;
  final int page;
  final int totalPages;
  final int total;
  final bool loadingMore;

  /// True while a cancellation is in flight.
  final bool busy;

  bool get hasMore => page < totalPages;

  /// Still holding a table, newest sitting first.
  List<ReservationSummary> get live =>
      [for (final b in bookings) if (b.status.isLive) b];

  List<ReservationSummary> get past =>
      [for (final b in bookings) if (!b.status.isLive) b];

  MyBookingsState copyWith({
    BookingsStatus? status,
    List<ReservationSummary>? bookings,
    ReservationDetail? detail,
    ApiFailure? failure,
    int? page,
    int? totalPages,
    int? total,
    bool? loadingMore,
    bool? busy,
    bool clearFailure = false,
    bool clearDetail = false,
  }) {
    return MyBookingsState(
      status: status ?? this.status,
      bookings: bookings ?? this.bookings,
      detail: clearDetail ? null : (detail ?? this.detail),
      failure: clearFailure ? null : (failure ?? this.failure),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
      busy: busy ?? this.busy,
    );
  }

  @override
  List<Object?> get props => [
    status,
    bookings,
    detail,
    failure,
    page,
    totalPages,
    total,
    loadingMore,
    busy,
  ];
}

/// The customer's bookings, and the one they have open.
///
/// The polling rule from the guide, exactly: refresh a **pending** booking every
/// ten seconds while its screen is visible and the app is in the foreground, stop
/// the moment it is anything else, and never run a permanent background timer.
/// There is no realtime channel for bookings, so this is the only way an approval
/// reaches the screen — but a booking that has been answered has nothing left to
/// watch for.
class MyBookingsCubit extends Cubit<MyBookingsState> {
  MyBookingsCubit({required ReservationRepository repository})
    : _repository = repository,
      super(const MyBookingsState());

  final ReservationRepository _repository;

  Timer? _poll;

  /// How often a pending booking is re-read. The guide's number.
  static const Duration pollInterval = Duration(seconds: 10);

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: BookingsStatus.loading, clearFailure: true));
    }

    try {
      final page = await _repository.myReservations(page: 1, pageSize: 20);
      emit(
        state.copyWith(
          status: BookingsStatus.ready,
          bookings: page.items,
          page: page.page,
          totalPages: page.totalPages,
          total: page.total,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.bookings.isNotEmpty
              ? BookingsStatus.ready
              : BookingsStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true));

    try {
      final next = await _repository.myReservations(
        page: state.page + 1,
        pageSize: 20,
      );
      emit(
        state.copyWith(
          bookings: [...state.bookings, ...next.items],
          page: next.page,
          totalPages: next.totalPages,
          total: next.total,
          loadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      // The rows already on screen stay: failing to fetch page three is no
      // reason to take pages one and two away.
      emit(state.copyWith(loadingMore: false, failure: failure));
    }
  }

  /// Opens one booking and starts watching it if it is still pending.
  Future<void> open(String id) async {
    emit(state.copyWith(clearDetail: true, clearFailure: true));
    await refreshDetail(id);
    _restartPolling(id);
  }

  /// Re-reads the open booking. Replaces the whole object rather than patching
  /// its status — `can_cancel`, `approved_at` and the reason all move together.
  Future<void> refreshDetail(String id) async {
    try {
      final detail = await _repository.reservation(id);
      emit(state.copyWith(detail: detail, clearFailure: true));
      _adoptSummary(detail);
      if (!detail.status.isLive || detail.status != ReservationStatus.pending) {
        _stopPolling();
      }
    } on ApiFailure catch (failure) {
      emit(state.copyWith(failure: failure));
      _stopPolling();
    }
  }

  /// Called when the screen is disposed or the app goes to the background.
  void stopWatching() => _stopPolling();

  /// Called when the screen resumes: one immediate read, then polling again if
  /// it is still pending.
  Future<void> resumeWatching() async {
    final id = state.detail?.id;
    if (id == null) return;
    await refreshDetail(id);
    _restartPolling(id);
  }

  void _restartPolling(String id) {
    _stopPolling();
    if (state.detail?.status != ReservationStatus.pending) return;
    _poll = Timer.periodic(pollInterval, (_) {
      if (!isClosed) refreshDetail(id);
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  /// Cancels a pending request.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> cancel(String id, {String? reason}) async {
    if (state.busy) return null;
    emit(state.copyWith(busy: true));

    try {
      final cancelled = await _repository.cancel(id, reason: reason);
      emit(state.copyWith(detail: cancelled, busy: false));
      _adoptSummary(cancelled);
      _stopPolling();
      // The list's counts and this booking's row both moved.
      await load(silent: true);
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busy: false));
      // Staff approved it between the screen loading and the button being
      // pressed. Re-reading is what makes the screen agree with the server.
      if (BookingErrorCodes.meansReloadBooking(failure.code)) {
        await refreshDetail(id);
      }
      return failure.message;
    }
  }

  /// Keeps the row in the list in step with the detail just fetched.
  void _adoptSummary(ReservationDetail detail) {
    if (!state.bookings.any((b) => b.id == detail.id)) return;
    emit(
      state.copyWith(
        bookings: [
          for (final booking in state.bookings)
            if (booking.id == detail.id) detail else booking,
        ],
      ),
    );
  }
}
