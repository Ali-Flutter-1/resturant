import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/page_data.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';

class ApiReservationRepository implements ReservationRepository {
  ApiReservationRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<Availability> availability({
    required DateTime date,
    int? guests,
  }) async {
    final data = await _client.object(
      ApiConstants.reservationAvailability,
      query: {
        // A calendar date, formatted by hand. `toIso8601String()` would send an
        // instant and shift the day for anyone east or west of the restaurant.
        'date': apiDate(date),
        'guests': ?guests,
      },
    );
    return Availability.fromJson(data);
  }

  @override
  Future<ReservationDetail> request({
    required String slotId,
    required int guests,
    required String contactName,
    required String contactPhone,
    String? specialRequests,
  }) async {
    final data = await _client.object(
      ApiConstants.reservations,
      method: 'POST',
      body: {
        'slot_id': slotId,
        'guests': guests,
        'contact_name': contactName.trim(),
        'contact_phone': contactPhone.trim(),
        'special_requests': ?_orNull(specialRequests),
      },
    );
    return ReservationDetail.fromJson(data);
  }

  @override
  Future<PageData<ReservationSummary>> myReservations({
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _client.page(
      ApiConstants.reservations,
      query: {'page': page, 'page_size': pageSize.clamp(1, 100)},
    );
    return data.map(ReservationSummary.fromJson);
  }

  @override
  Future<ReservationDetail> reservation(String id) async =>
      ReservationDetail.fromJson(
        await _client.object(ApiConstants.reservation(id)),
      );

  @override
  Future<ReservationDetail> cancel(String id, {String? reason}) async {
    final tidied = _orNull(reason);
    final data = await _client.object(
      ApiConstants.reservationCancel(id),
      method: 'POST',
      // `{}` when there is nothing to say. The field is optional, and sending an
      // empty string would store one.
      body: {'reason': ?tidied},
    );
    return ReservationDetail.fromJson(data);
  }

  @override
  Future<PageData<ReservationSummary>> adminReservations({
    int page = 1,
    int pageSize = 20,
    DateTime? date,
    ReservationStatus? status,
  }) async {
    final data = await _client.page(
      ApiConstants.adminReservations,
      query: {
        'page': page,
        'page_size': pageSize.clamp(1, 100),
        'date': ?(date == null ? null : apiDate(date)),
        'status': ?status?.apiValue,
      },
    );
    return data.map(ReservationSummary.fromJson);
  }

  @override
  Future<ReservationStats> adminStats() async => ReservationStats.fromJson(
    await _client.object(ApiConstants.adminReservationStats),
  );

  @override
  Future<ReservationDetail> adminReservation(String id) async =>
      ReservationDetail.fromJson(
        await _client.object(ApiConstants.adminReservation(id)),
      );

  @override
  Future<ReservationDetail> updateStatus(
    String id, {
    required ReservationStatus status,
    String? note,
  }) async {
    final data = await _client.object(
      ApiConstants.adminReservationStatus(id),
      method: 'PATCH',
      body: {'status': status.apiValue, 'note': _orNull(note)},
    );
    return ReservationDetail.fromJson(data);
  }

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
