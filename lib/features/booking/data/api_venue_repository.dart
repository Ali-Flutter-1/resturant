import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/reservation.dart' show apiDate;
import '../domain/reservation_repository.dart';
import '../domain/venue_table.dart';

class ApiVenueRepository implements VenueRepository {
  ApiVenueRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<VenueTable>> tables({bool includeArchived = false}) async {
    final rows = await _client.list(
      ApiConstants.adminTables,
      query: {'include_archived': includeArchived},
    );
    return rows.map(VenueTable.fromJson).toList();
  }

  @override
  Future<VenueTable> createTable(VenueTable table) async => VenueTable.fromJson(
    await _client.object(
      ApiConstants.adminTables,
      method: 'POST',
      body: table.toJson(),
    ),
  );

  @override
  Future<VenueTable> updateTable(
    String id,
    Map<String, dynamic> changes,
  ) async => VenueTable.fromJson(
    await _client.object(
      ApiConstants.adminTable(id),
      method: 'PATCH',
      body: changes,
    ),
  );

  @override
  Future<void> archiveTable(String id) async {
    // `send`, not `object`: this route answers `data: null`.
    await _client.send(ApiConstants.adminTable(id), method: 'DELETE');
  }

  @override
  Future<VenueTable> restoreTable(String id) async => VenueTable.fromJson(
    await _client.object(ApiConstants.adminTableRestore(id), method: 'POST'),
  );

  @override
  Future<List<VenueSlot>> slots({
    DateTime? fromDate,
    DateTime? toDate,
    String? tableId,
  }) async {
    final rows = await _client.list(
      ApiConstants.adminTableSlots,
      query: {
        'from_date': ?(fromDate == null ? null : apiDate(fromDate)),
        'to_date': ?(toDate == null ? null : apiDate(toDate)),
        'table_id': ?tableId,
      },
    );
    return rows.map(VenueSlot.fromJson).toList();
  }

  @override
  Future<VenueSlot> createSlot({
    required String tableId,
    required DateTime serviceDate,
    required String startTime,
    int durationMinutes = 90,
    int bufferMinutes = 0,
    int? pricePence,
    String? notes,
    bool isActive = true,
  }) async {
    final data = await _client.object(
      ApiConstants.adminTableSlots,
      method: 'POST',
      body: {
        'table_id': tableId,
        'service_date': apiDate(serviceDate),
        'start_time': _withSeconds(startTime),
        'duration_minutes': durationMinutes,
        'buffer_minutes': bufferMinutes,
        // Omitted rather than sent as 0 when unset: null makes the backend copy
        // the table's own price, and 0 would silently make a paid table free.
        'price_pence': pricePence,
        'notes': ?_orNull(notes),
        'is_active': isActive,
      },
    );
    return VenueSlot.fromJson(data);
  }

  @override
  Future<VenueSlot> updateSlot(String id, Map<String, dynamic> changes) async =>
      VenueSlot.fromJson(
        await _client.object(
          ApiConstants.adminTableSlot(id),
          method: 'PATCH',
          body: changes,
        ),
      );

  @override
  Future<void> deleteSlot(String id) async {
    await _client.send(ApiConstants.adminTableSlot(id), method: 'DELETE');
  }

  @override
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
  }) async {
    final data = await _client.object(
      ApiConstants.adminTableSlotsGenerate,
      method: 'POST',
      body: {
        // Both omitted when empty, which the API reads as "every active table"
        // and "every day". Sending `[]` would mean the opposite.
        if (tableIds.isNotEmpty) 'table_ids': tableIds,
        if (weekdays.isNotEmpty)
          'weekdays': [for (final day in weekdays) day.apiValue],
        'from_date': apiDate(fromDate),
        'to_date': apiDate(toDate),
        'first_sitting': _withSeconds(firstSitting),
        // The last *start* time, not closing time. The final sitting runs on
        // past it by its duration and buffer.
        'last_sitting': _withSeconds(lastSitting),
        'turn_minutes': turnMinutes,
        'buffer_minutes': bufferMinutes,
        'price_pence': pricePence,
      },
    );
    return SlotGenerateResult.fromJson(data);
  }

  static String _withSeconds(String value) =>
      value.split(':').length == 2 ? '$value:00' : value;

  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
