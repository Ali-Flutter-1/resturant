import '../../../core/network/page_data.dart';
import 'reservation.dart';
import 'venue_table.dart';

/// Table bookings.
///
/// Customer and staff routes share one interface because they share one screen
/// stack's worth of models; what a caller may actually do is decided by the
/// backend from the bearer token, not by which method is in reach.
abstract interface class ReservationRepository {
  /// Every table and sitting for a day, including the ones that cannot be
  /// chosen — a disabled slot with a reason is a schedule, a missing one is a
  /// gap the customer cannot explain.
  Future<Availability> availability({required DateTime date, int? guests});

  /// Requests a slot. Answers 201 with a **pending** booking, never a confirmed
  /// one.
  Future<ReservationDetail> request({
    required String slotId,
    required int guests,
    required String contactName,
    required String contactPhone,
    String? specialRequests,
  });

  Future<PageData<ReservationSummary>> myReservations({
    int page = 1,
    int pageSize = 20,
  });

  Future<ReservationDetail> reservation(String id);

  /// Customer cancellation. Allowed only while pending; the server refuses
  /// afterwards with `RESERVATION_ALREADY_APPROVED`.
  Future<ReservationDetail> cancel(String id, {String? reason});

  // ------------------------------------------------------------ staff / admin

  Future<PageData<ReservationSummary>> adminReservations({
    int page = 1,
    int pageSize = 20,
    DateTime? date,
    ReservationStatus? status,
  });

  Future<ReservationStats> adminStats();

  Future<ReservationDetail> adminReservation(String id);

  /// Moves a booking on. [note] is mandatory for reject, cancel and no-show —
  /// the API answers 422 without one, and the customer is shown it as the
  /// reason.
  Future<ReservationDetail> updateStatus(
    String id, {
    required ReservationStatus status,
    String? note,
  });
}

/// Physical tables and the sitting schedule. **Admin only** — staff can work
/// reservations but cannot change the room or the timetable.
abstract interface class VenueRepository {
  Future<List<VenueTable>> tables({bool includeArchived = false});

  Future<VenueTable> createTable(VenueTable table);

  /// Sends only [changes], not the whole object: a PATCH that resends every
  /// field would overwrite whatever another admin altered in between.
  Future<VenueTable> updateTable(String id, Map<String, dynamic> changes);

  /// Soft delete. Refused while upcoming reservations exist.
  Future<void> archiveTable(String id);

  /// Un-archives. Deliberately does not make the table live again — the API
  /// leaves that as a separate decision, so the caller must PATCH `is_active`.
  Future<VenueTable> restoreTable(String id);

  Future<List<VenueSlot>> slots({
    DateTime? fromDate,
    DateTime? toDate,
    String? tableId,
  });

  Future<VenueSlot> createSlot({
    required String tableId,
    required DateTime serviceDate,
    required String startTime,
    int durationMinutes = 90,
    int bufferMinutes = 0,
    int? pricePence,
    String? notes,
    bool isActive = true,
  });

  Future<VenueSlot> updateSlot(String id, Map<String, dynamic> changes);

  /// Refused while a booking holds the slot. Close it instead.
  Future<void> deleteSlot(String id);

  Future<SlotGenerateResult> generateSlots({
    required DateTime fromDate,
    required DateTime toDate,
    required String firstSitting,
    required String lastSitting,
    required int turnMinutes,
    int bufferMinutes = 0,
    List<String> tableIds = const [],
    List<SlotWeekday> weekdays = const [],
    int? pricePence,
  });
}
