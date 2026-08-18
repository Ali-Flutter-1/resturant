import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/page_data.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

enum AdminBookingsStatus { loading, ready, failure }

class AdminBookingsState extends Equatable {
  const AdminBookingsState({
    required this.date,
    this.status = AdminBookingsStatus.loading,
    this.bookings = const [],
    this.stats = const ReservationStats(),
    this.filter,
    this.detail,
    this.failure,
    this.busyIds = const {},
  });

  /// The day's sheet. Null means every upcoming booking rather than one date.
  final DateTime? date;

  final AdminBookingsStatus status;
  final List<ReservationSummary> bookings;
  final ReservationStats stats;

  /// Null shows every status.
  final ReservationStatus? filter;

  /// The booking open in the sheet, in full — a summary carries no contact
  /// details, requests or reason.
  final ReservationDetail? detail;

  final ApiFailure? failure;

  /// Bookings with a write in flight, so only that row is disabled.
  final Set<String> busyIds;

  AdminBookingsState copyWith({
    DateTime? date,
    AdminBookingsStatus? status,
    List<ReservationSummary>? bookings,
    ReservationStats? stats,
    ReservationStatus? filter,
    ReservationDetail? detail,
    ApiFailure? failure,
    Set<String>? busyIds,
    bool clearDate = false,
    bool clearFilter = false,
    bool clearFailure = false,
    bool clearDetail = false,
  }) {
    return AdminBookingsState(
      date: clearDate ? null : (date ?? this.date),
      status: status ?? this.status,
      bookings: bookings ?? this.bookings,
      stats: stats ?? this.stats,
      filter: clearFilter ? null : (filter ?? this.filter),
      detail: clearDetail ? null : (detail ?? this.detail),
      failure: clearFailure ? null : (failure ?? this.failure),
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    date,
    status,
    bookings,
    stats,
    filter,
    detail,
    failure,
    busyIds,
  ];
}

/// The staff booking sheet.
///
/// Mirrors the kitchen queue: a filter, a stats strip, and a detail sheet that
/// offers only the moves the current status allows. The two rules that matter:
///
///  * **Adopt what the server returned.** Every mutation answers with the whole
///    booking; the row takes that rather than assuming the move stuck.
///  * **A 409 is expected, not exceptional.** Another device can act first, so
///    an invalid transition re-reads instead of showing a dead end.
class AdminBookingsCubit extends Cubit<AdminBookingsState> {
  AdminBookingsCubit({
    required ReservationRepository repository,
    DateTime? today,
  }) : _repository = repository,
       _today = today,
       super(
         const AdminBookingsState(
           date: null,
           // Pending first: an unanswered request is holding a table, and it is
           // the only thing on this screen with a clock running on it.
           filter: ReservationStatus.pending,
         ),
       );

  final ReservationRepository _repository;
  final DateTime? _today;

  DateTime get today {
    final now = _today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(
        state.copyWith(status: AdminBookingsStatus.loading, clearFailure: true),
      );
    }

    try {
      final results = await Future.wait<Object>([
        _repository.adminReservations(
          page: 1,
          pageSize: 100,
          date: state.date,
          status: state.filter,
        ),
        _repository.adminStats(),
      ]);

      emit(
        state.copyWith(
          status: AdminBookingsStatus.ready,
          bookings: (results[0] as PageData<ReservationSummary>).items,
          stats: results[1] as ReservationStats,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.bookings.isNotEmpty
              ? AdminBookingsStatus.ready
              : AdminBookingsStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> setFilter(ReservationStatus? status) async {
    if (status == state.filter) return;
    emit(
      status == null
          ? state.copyWith(clearFilter: true)
          : state.copyWith(filter: status),
    );
    await load(silent: state.bookings.isNotEmpty);
  }

  Future<void> setDate(DateTime? date) async {
    final day = date == null ? null : DateTime(date.year, date.month, date.day);
    if (day == state.date) return;
    emit(
      day == null ? state.copyWith(clearDate: true) : state.copyWith(date: day),
    );
    await load(silent: state.bookings.isNotEmpty);
  }

  /// Opens one booking in full.
  Future<void> open(String id) async {
    emit(state.copyWith(clearDetail: true, clearFailure: true));
    try {
      emit(state.copyWith(detail: await _repository.adminReservation(id)));
    } on ApiFailure catch (failure) {
      emit(state.copyWith(failure: failure));
    }
  }

  void closeDetail() => emit(state.copyWith(clearDetail: true));

  /// Moves a booking on.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> updateStatus(
    String id, {
    required ReservationStatus status,
    String? note,
  }) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      final updated = await _repository.updateStatus(
        id,
        status: status,
        note: note,
      );
      emit(
        state.copyWith(
          detail: updated,
          busyIds: {...state.busyIds}..remove(id),
        ),
      );
      // The row's status and every counter moved, and the filter may no longer
      // match — an approved request leaves the pending list.
      await load(silent: true);
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      // Another device got there first. Re-reading is what makes the buttons
      // agree with reality rather than offering the same refused move again.
      if (BookingErrorCodes.meansReloadBooking(failure.code)) {
        await open(id);
        await load(silent: true);
      }
      return failure.message;
    }
  }
}
