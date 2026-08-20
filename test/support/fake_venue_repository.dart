import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/booking/domain/reservation_repository.dart';
import 'package:practice/features/booking/domain/venue_table.dart';

/// Tables and sittings, in memory.
class FakeVenueRepository implements VenueRepository {
  FakeVenueRepository({
    List<VenueTable>? tables,
    List<VenueSlot>? slots,
    this.delay,
  }) : _tables = tables ?? [...defaultTables],
       _slots = slots ?? [...defaultSlots];

  final Duration? delay;

  static final defaultTables = <VenueTable>[
    const VenueTable(
      id: 't1',
      name: 'Window Table 1',
      seats: 4,
      area: TableArea.window,
      description: 'Beside the front window',
    ),
    const VenueTable(
      id: 't2',
      name: 'Snug',
      seats: 2,
      area: TableArea.indoor,
      bookingPricePence: 500,
      isActive: false,
    ),
    const VenueTable(
      id: 't3',
      name: 'Old Corner',
      seats: 6,
      area: TableArea.indoor,
      isActive: false,
      isArchived: true,
    ),
  ];

  static final defaultSlots = <VenueSlot>[
    VenueSlot(
      id: 's1',
      tableId: 't1',
      tableName: 'Window Table 1',
      serviceDate: DateTime(2026, 8, 20),
      startTime: '19:00:00',
      durationMinutes: 90,
      bufferMinutes: 15,
      pricePence: 0,
    ),
    // Held by a live booking, so it may be closed but never deleted or re-timed.
    VenueSlot(
      id: 's2',
      tableId: 't1',
      tableName: 'Window Table 1',
      serviceDate: DateTime(2026, 8, 20),
      startTime: '20:45:00',
      durationMinutes: 90,
      bufferMinutes: 15,
      pricePence: 0,
      isBooked: true,
    ),
  ];

  List<VenueTable> _tables;
  List<VenueSlot> _slots;

  ApiFailure? failure;
  ApiFailure? writeFailure;

  int tableCalls = 0;
  int slotCalls = 0;
  bool? lastIncludeArchived;
  Map<String, Object?>? lastSlotQuery;
  Map<String, dynamic>? lastTableCreate;
  Map<String, dynamic>? lastTablePatch;
  Map<String, dynamic>? lastSlotPatch;
  Map<String, dynamic>? lastSlotCreate;
  Map<String, Object?>? lastGenerate;
  String? archivedId;
  String? restoredId;
  String? deletedSlotId;

  SlotGenerateResult generateResult = const SlotGenerateResult(
    created: 84,
    skipped: 6,
    tables: 2,
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
  Future<List<VenueTable>> tables({bool includeArchived = false}) async {
    tableCalls++;
    lastIncludeArchived = includeArchived;
    await _wait();
    _check();
    return [
      for (final table in _tables)
        if (includeArchived || !table.isArchived) table,
    ];
  }

  @override
  Future<VenueTable> createTable(VenueTable table) async {
    lastTableCreate = table.toJson();
    await _wait();
    _checkWrite();
    final created = VenueTable(
      id: 't${_tables.length + 1}',
      name: table.name,
      seats: table.seats,
      area: table.area,
      description: table.description,
      bookingPricePence: table.bookingPricePence,
      sortOrder: table.sortOrder,
      isActive: table.isActive,
    );
    _tables = [..._tables, created];
    return created;
  }

  @override
  Future<VenueTable> updateTable(
    String id,
    Map<String, dynamic> changes,
  ) async {
    lastTablePatch = changes;
    await _wait();
    _checkWrite();
    final existing = _tables.firstWhere((t) => t.id == id);
    final updated = existing.copyWith(
      name: changes['name'] as String?,
      seats: (changes['seats'] as num?)?.toInt(),
      isActive: changes['is_active'] as bool?,
      bookingPricePence: (changes['booking_price_pence'] as num?)?.toInt(),
    );
    _tables = [
      for (final t in _tables)
        if (t.id == id) updated else t,
    ];
    return updated;
  }

  @override
  Future<void> archiveTable(String id) async {
    archivedId = id;
    await _wait();
    _checkWrite();
    _tables = [
      for (final t in _tables)
        if (t.id == id)
          VenueTable(
            id: t.id,
            name: t.name,
            seats: t.seats,
            area: t.area,
            description: t.description,
            bookingPricePence: t.bookingPricePence,
            sortOrder: t.sortOrder,
            isActive: false,
            isArchived: true,
          )
        else
          t,
    ];
  }

  @override
  Future<VenueTable> restoreTable(String id) async {
    restoredId = id;
    await _wait();
    _checkWrite();
    final existing = _tables.firstWhere((t) => t.id == id);
    // Un-archived but deliberately still hidden, exactly as the API behaves.
    final restored = VenueTable(
      id: existing.id,
      name: existing.name,
      seats: existing.seats,
      area: existing.area,
      description: existing.description,
      bookingPricePence: existing.bookingPricePence,
      sortOrder: existing.sortOrder,
      isActive: false,
      isArchived: false,
    );
    _tables = [
      for (final t in _tables)
        if (t.id == id) restored else t,
    ];
    return restored;
  }

  @override
  Future<List<VenueSlot>> slots({
    DateTime? fromDate,
    DateTime? toDate,
    String? tableId,
  }) async {
    slotCalls++;
    lastSlotQuery = {'from': fromDate, 'to': toDate, 'table_id': tableId};
    await _wait();
    _check();
    return [
      for (final slot in _slots)
        if (tableId == null || slot.tableId == tableId) slot,
    ];
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
    lastSlotCreate = {
      'table_id': tableId,
      'service_date': serviceDate,
      'start_time': startTime,
      'duration_minutes': durationMinutes,
      'buffer_minutes': bufferMinutes,
      'price_pence': pricePence,
      'notes': notes,
      'is_active': isActive,
    };
    await _wait();
    _checkWrite();
    final created = VenueSlot(
      id: 's${_slots.length + 1}',
      tableId: tableId,
      tableName: _tables.firstWhere((t) => t.id == tableId).name,
      serviceDate: serviceDate,
      startTime: startTime,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      pricePence: pricePence ?? 0,
      notes: notes,
      isActive: isActive,
    );
    _slots = [..._slots, created];
    return created;
  }

  @override
  Future<VenueSlot> updateSlot(String id, Map<String, dynamic> changes) async {
    lastSlotPatch = changes;
    await _wait();
    _checkWrite();
    final existing = _slots.firstWhere((s) => s.id == id);
    final updated = VenueSlot(
      id: existing.id,
      tableId: existing.tableId,
      tableName: existing.tableName,
      serviceDate: existing.serviceDate,
      startTime: existing.startTime,
      durationMinutes:
          (changes['duration_minutes'] as num?)?.toInt() ??
          existing.durationMinutes,
      bufferMinutes:
          (changes['buffer_minutes'] as num?)?.toInt() ??
          existing.bufferMinutes,
      pricePence: existing.pricePence,
      notes: existing.notes,
      isActive: changes['is_active'] as bool? ?? existing.isActive,
      isBooked: existing.isBooked,
    );
    _slots = [
      for (final s in _slots)
        if (s.id == id) updated else s,
    ];
    return updated;
  }

  @override
  Future<void> deleteSlot(String id) async {
    deletedSlotId = id;
    await _wait();
    _checkWrite();
    _slots = [
      for (final s in _slots)
        if (s.id != id) s,
    ];
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
    lastGenerate = {
      'from': fromDate,
      'to': toDate,
      'first': firstSitting,
      'last': lastSitting,
      'turn': turnMinutes,
      'buffer': bufferMinutes,
      'table_ids': tableIds,
      'weekdays': [for (final d in weekdays) d.apiValue],
      'price_pence': pricePence,
    };
    await _wait();
    _checkWrite();
    return generateResult;
  }
}
