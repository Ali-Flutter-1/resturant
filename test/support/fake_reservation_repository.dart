import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/network/page_data.dart';
import 'package:practice/features/booking/domain/reservation.dart';
import 'package:practice/features/booking/domain/reservation_repository.dart';

/// Table bookings, in memory.
///
/// Returns copies rather than its own lists, for the same reason as the other
/// fakes: a shared reference lets a write mutate the list already in cubit
/// state, Equatable then sees no change, and `emit` silently does nothing.
class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository({
    Availability? availability,
    List<ReservationSummary>? bookings,
    this.delay,
  }) : _availability = availability ?? defaultAvailability(),
       _bookings = bookings ?? [];

  final Duration? delay;

  /// One table with two free sittings and two that cannot be taken, so a test
  /// can check that the disabled ones are still drawn with their reason.
  static Availability defaultAvailability({DateTime? date, int? guests}) {
    final day = date ?? DateTime(2026, 8, 20);
    return Availability(
      serviceDate: day,
      guests: guests,
      tables: const [
        AvailabilityTable(
          id: 't1',
          name: 'Window Table 1',
          seats: 4,
          area: 'window',
          description: 'Beside the front window',
          sittings: [
            AvailabilitySitting(
              slotId: 's1',
              startTime: '19:00:00',
              durationMinutes: 90,
              bufferMinutes: 15,
              pricePence: 0,
              isAvailable: true,
            ),
            AvailabilitySitting(
              slotId: 's2',
              startTime: '20:30:00',
              durationMinutes: 90,
              bufferMinutes: 15,
              pricePence: 0,
              isAvailable: false,
              unavailableReason: UnavailableReason.booked,
            ),
          ],
        ),
        AvailabilityTable(
          id: 't2',
          name: 'Snug',
          seats: 2,
          area: 'indoor',
          sittings: [
            AvailabilitySitting(
              slotId: 's3',
              startTime: '19:00:00',
              durationMinutes: 90,
              bufferMinutes: 0,
              pricePence: 500,
              isAvailable: true,
            ),
            AvailabilitySitting(
              slotId: 's4',
              startTime: '21:00:00',
              durationMinutes: 90,
              bufferMinutes: 0,
              pricePence: 500,
              isAvailable: false,
              unavailableReason: UnavailableReason.tooSmall,
            ),
          ],
        ),
      ],
    );
  }

  static ReservationDetail detail({
    String id = 'r1',
    String reference = 'ABCD-EFGH',
    ReservationStatus status = ReservationStatus.pending,
    bool canCancel = true,
    String? cancellationReason,
    DateTime? expiresAt,
    int guests = 4,
  }) => ReservationDetail(
    id: id,
    reference: reference,
    status: status,
    tableName: 'Window Table 1',
    serviceDate: DateTime(2026, 8, 20),
    startTime: '19:00:00',
    guests: guests,
    pricePence: 0,
    slotId: 's1',
    contactName: 'Ali Hassan',
    contactPhone: '07700 900123',
    canCancel: canCancel,
    cancellationReason: cancellationReason,
    expiresAt: expiresAt,
    createdAt: DateTime(2026, 8, 13, 10),
  );

  Availability _availability;
  List<ReservationSummary> _bookings;

  ApiFailure? failure;

  /// Fails only the write, so a test can load fine and be refused on the move.
  ApiFailure? writeFailure;

  int availabilityCalls = 0;
  int listCalls = 0;
  int detailCalls = 0;
  final List<Map<String, Object?>> availabilityQueries = [];
  Map<String, Object?>? lastRequest;
  Map<String, Object?>? lastStatusChange;
  Map<String, Object?>? lastCancel;

  /// What the next request answers with.
  ReservationDetail requestResult = detail();

  ReservationStats stats = const ReservationStats(
    pendingApproval: 3,
    todayConfirmed: 12,
    todayGuests: 38,
    upcoming: 51,
    seatedNow: 4,
  );

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  void _checkWrite() {
    final error = writeFailure ?? failure;
    if (error != null) throw error;
  }

  @override
  Future<Availability> availability({
    required DateTime date,
    int? guests,
  }) async {
    availabilityCalls++;
    availabilityQueries.add({'date': apiDate(date), 'guests': guests});
    await _wait();
    _check();
    return Availability(
      serviceDate: date,
      guests: guests,
      tables: List.of(_availability.tables),
    );
  }

  /// Replaces what availability answers with, for a test that changes the day.
  set availabilityResult(Availability value) => _availability = value;

  @override
  Future<ReservationDetail> request({
    required String slotId,
    required int guests,
    required String contactName,
    required String contactPhone,
    String? specialRequests,
  }) async {
    lastRequest = {
      'slot_id': slotId,
      'guests': guests,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'special_requests': specialRequests,
    };
    await _wait();
    _checkWrite();
    return requestResult;
  }

  @override
  Future<PageData<ReservationSummary>> myReservations({
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls++;
    await _wait();
    _check();
    return PageData(
      items: List.of(_bookings),
      page: page,
      pageSize: pageSize,
      total: _bookings.length,
      totalPages: _bookings.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<ReservationDetail> reservation(String id) async {
    detailCalls++;
    await _wait();
    _check();
    return requestResult;
  }

  @override
  Future<ReservationDetail> cancel(String id, {String? reason}) async {
    lastCancel = {'id': id, 'reason': reason};
    await _wait();
    _checkWrite();
    requestResult = detail(
      id: id,
      status: ReservationStatus.cancelled,
      canCancel: false,
      cancellationReason: reason,
    );
    _replace(requestResult);
    return requestResult;
  }

  @override
  Future<PageData<ReservationSummary>> adminReservations({
    int page = 1,
    int pageSize = 20,
    DateTime? date,
    ReservationStatus? status,
  }) async {
    listCalls++;
    availabilityQueries.add({
      'date': date == null ? null : apiDate(date),
      'status': status?.apiValue,
    });
    await _wait();
    _check();

    final rows = status == null
        ? List.of(_bookings)
        : [
            for (final b in _bookings)
              if (b.status == status) b,
          ];
    return PageData(
      items: rows,
      page: page,
      pageSize: pageSize,
      total: rows.length,
      totalPages: rows.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<ReservationStats> adminStats() async {
    await _wait();
    _check();
    return stats;
  }

  @override
  Future<ReservationDetail> adminReservation(String id) async {
    detailCalls++;
    await _wait();
    _check();
    return requestResult;
  }

  @override
  Future<ReservationDetail> updateStatus(
    String id, {
    required ReservationStatus status,
    String? note,
  }) async {
    lastStatusChange = {'id': id, 'status': status.apiValue, 'note': note};
    await _wait();
    _checkWrite();
    requestResult = detail(id: id, status: status, cancellationReason: note);
    _replace(requestResult);
    return requestResult;
  }

  void _replace(ReservationSummary updated) {
    _bookings = [
      for (final booking in _bookings)
        if (booking.id == updated.id) updated else booking,
    ];
  }
}
