import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

enum BookingStage {
  /// Choosing a date and a party size.
  choosing,

  /// Availability is being read.
  loading,

  /// Tables and sittings are on screen.
  ready,

  /// The request is with the server.
  submitting,

  /// Accepted — and **pending**, not confirmed.
  requested,

  failure,
}

class BookingState extends Equatable {
  const BookingState({
    required this.date,
    this.guests = 2,
    this.stage = BookingStage.choosing,
    this.availability,
    this.selectedSlotId,
    this.reservation,
    this.failure,
    this.fieldErrors = const {},
  });

  /// The restaurant's calendar date being looked at.
  final DateTime date;

  final int guests;
  final BookingStage stage;
  final Availability? availability;

  /// The chosen sitting. A slot id, never a table plus a time — the guide is
  /// explicit that the id is what identifies a sitting.
  final String? selectedSlotId;

  /// Set once the request exists.
  final ReservationDetail? reservation;

  final ApiFailure? failure;
  final Map<String, String> fieldErrors;

  bool get isLoading => stage == BookingStage.loading;
  bool get isSubmitting => stage == BookingStage.submitting;
  bool get canSubmit => selectedSlotId != null && !isSubmitting;

  /// The chosen sitting, looked up in the newest availability. Null once a
  /// reload has taken it away, which is how the selection clears itself.
  AvailabilitySitting? get selectedSitting {
    final id = selectedSlotId;
    if (id == null) return null;
    for (final table in availability?.tables ?? const <AvailabilityTable>[]) {
      for (final sitting in table.sittings) {
        if (sitting.slotId == id) return sitting;
      }
    }
    return null;
  }

  AvailabilityTable? get selectedTable {
    final id = selectedSlotId;
    if (id == null) return null;
    for (final table in availability?.tables ?? const <AvailabilityTable>[]) {
      if (table.sittings.any((s) => s.slotId == id)) return table;
    }
    return null;
  }

  BookingState copyWith({
    DateTime? date,
    int? guests,
    BookingStage? stage,
    Availability? availability,
    String? selectedSlotId,
    ReservationDetail? reservation,
    ApiFailure? failure,
    Map<String, String>? fieldErrors,
    bool clearFailure = false,
    bool clearSelection = false,
  }) {
    return BookingState(
      date: date ?? this.date,
      guests: guests ?? this.guests,
      stage: stage ?? this.stage,
      availability: availability ?? this.availability,
      selectedSlotId: clearSelection
          ? null
          : (selectedSlotId ?? this.selectedSlotId),
      reservation: reservation ?? this.reservation,
      failure: clearFailure ? null : (failure ?? this.failure),
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  @override
  List<Object?> get props => [
    date,
    guests,
    stage,
    availability,
    selectedSlotId,
    reservation,
    failure,
    fieldErrors,
  ];
}

/// Choosing a sitting and asking for it.
///
/// Three rules from the guide shape this:
///
///  * **Availability is a snapshot.** Another customer can take the slot between
///    it appearing free and this one pressing the button, so `SLOT_ALREADY_BOOKED`
///    is an expected answer — it clears the selection and reloads rather than
///    showing a generic error.
///  * **Ignore a stale response.** Party size and date can change faster than the
///    network answers, so each request carries a generation and a late reply for
///    an old one is dropped.
///  * **Never retry the request automatically.** `POST /reservations` has no
///    idempotency key, so a retry after an unknown timeout can book two tables.
///    The customer is told to check their bookings instead.
class BookingCubit extends Cubit<BookingState> {
  BookingCubit({required ReservationRepository repository, DateTime? today})
    : _repository = repository,
      super(BookingState(date: _startOfDay(today ?? DateTime.now())));

  final ReservationRepository _repository;

  int _generation = 0;

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<void> load() async {
    final generation = ++_generation;
    emit(state.copyWith(stage: BookingStage.loading, clearFailure: true));

    try {
      final availability = await _repository.availability(
        date: state.date,
        guests: state.guests,
      );
      if (generation != _generation) return;

      // A selection that is no longer bookable is dropped rather than carried
      // forward into a request the server would refuse.
      final chosen = state.selectedSlotId;
      final stillFree = availability.tables.any(
        (t) => t.sittings.any((s) => s.slotId == chosen && s.isAvailable),
      );

      emit(
        state.copyWith(
          stage: BookingStage.ready,
          availability: availability,
          clearFailure: true,
          clearSelection: !stillFree,
        ),
      );
    } on ApiFailure catch (failure) {
      if (generation != _generation) return;
      emit(state.copyWith(stage: BookingStage.failure, failure: failure));
    }
  }

  Future<void> setDate(DateTime date) async {
    final day = _startOfDay(date);
    if (day == state.date) return;
    // The selection belongs to the old day, so it goes with it.
    emit(state.copyWith(date: day, clearSelection: true));
    await load();
  }

  Future<void> setGuests(int guests) async {
    final party = guests.clamp(1, maxGuests);
    if (party == state.guests) return;
    // Kept, not cleared: a bigger party may still fit the same table, and the
    // reload marks it `too_small` if it does not.
    emit(state.copyWith(guests: party));
    await load();
  }

  /// The API's ceiling. Asking for more is refused, so the stepper stops here.
  static const int maxGuests = 30;

  void select(String slotId) {
    if (state.selectedSlotId == slotId) {
      return emit(state.copyWith(clearSelection: true));
    }
    emit(state.copyWith(selectedSlotId: slotId, clearFailure: true));
  }

  /// Asks for the chosen sitting.
  ///
  /// Returns null on success. The booking that comes back is **pending**.
  Future<ApiFailure?> submit({
    required String contactName,
    required String contactPhone,
    String? specialRequests,
  }) async {
    final slotId = state.selectedSlotId;
    if (slotId == null || state.isSubmitting) return null;

    emit(
      state.copyWith(
        stage: BookingStage.submitting,
        clearFailure: true,
        fieldErrors: const {},
      ),
    );

    try {
      final reservation = await _repository.request(
        slotId: slotId,
        guests: state.guests,
        contactName: contactName,
        contactPhone: contactPhone,
        specialRequests: specialRequests,
      );
      emit(
        state.copyWith(
          stage: BookingStage.requested,
          reservation: reservation,
          clearFailure: true,
        ),
      );
      return null;
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          stage: BookingStage.ready,
          failure: failure,
          fieldErrors: failure.fieldErrors,
        ),
      );

      // The slot went while the customer was filling the form. Clearing the
      // selection and reloading is the only useful answer — the button they
      // just pressed cannot succeed a second time.
      if (BookingErrorCodes.meansReloadAvailability(failure.code)) {
        emit(state.copyWith(clearSelection: true));
        await load();
      }
      return failure;
    }
  }

  /// Back to choosing, after a completed request.
  void startAgain() {
    emit(
      BookingState(
        date: state.date,
        guests: state.guests,
        stage: BookingStage.choosing,
      ),
    );
  }
}
