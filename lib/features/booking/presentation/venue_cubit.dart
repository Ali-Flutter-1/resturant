import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/reservation_repository.dart';
import '../domain/venue_table.dart';

enum VenueStatus { loading, ready, failure }

class VenueState extends Equatable {
  const VenueState({
    this.status = VenueStatus.loading,
    this.tables = const [],
    this.slots = const [],
    this.includeArchived = false,
    this.tableFilterId,
    this.from,
    this.to,
    this.failure,
    this.busyIds = const {},
  });

  final VenueStatus status;
  final List<VenueTable> tables;
  final List<VenueSlot> slots;

  /// Archived tables are hidden by default: they are history, not room to plan
  /// with.
  final bool includeArchived;

  /// Null shows every table's sittings.
  final String? tableFilterId;

  /// The schedule window being looked at.
  final DateTime? from;
  final DateTime? to;

  final ApiFailure? failure;

  /// Tables or slots with a write in flight, so only that row is disabled.
  final Set<String> busyIds;

  List<VenueTable> get liveTables => [
    for (final t in tables)
      if (!t.isArchived) t,
  ];

  /// Sittings grouped by day, in service order — which is how a schedule is
  /// read.
  Map<DateTime, List<VenueSlot>> get byDay {
    final grouped = <DateTime, List<VenueSlot>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.serviceDate, () => []).add(slot);
    }
    for (final day in grouped.values) {
      day.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  VenueState copyWith({
    VenueStatus? status,
    List<VenueTable>? tables,
    List<VenueSlot>? slots,
    bool? includeArchived,
    String? tableFilterId,
    DateTime? from,
    DateTime? to,
    ApiFailure? failure,
    Set<String>? busyIds,
    bool clearTableFilter = false,
    bool clearFailure = false,
  }) {
    return VenueState(
      status: status ?? this.status,
      tables: tables ?? this.tables,
      slots: slots ?? this.slots,
      includeArchived: includeArchived ?? this.includeArchived,
      tableFilterId: clearTableFilter
          ? null
          : (tableFilterId ?? this.tableFilterId),
      from: from ?? this.from,
      to: to ?? this.to,
      failure: clearFailure ? null : (failure ?? this.failure),
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    tables,
    slots,
    includeArchived,
    tableFilterId,
    from,
    to,
    failure,
    busyIds,
  ];
}

/// The room and the timetable. Admin only.
///
/// Two rules the API enforces and this mirrors:
///
///  * **A held sitting is closed, not deleted.** While a pending, confirmed or
///    seated booking holds a slot, deleting it or re-timing it is refused — and
///    rightly, since it would move a table out from under somebody already told
///    they have it. Setting `is_active: false` stops further sales and leaves the
///    existing booking alone.
///  * **Restoring a table does not make it live.** The API clears `archived_at`
///    and stops; whether customers see it again is a second decision.
class VenueCubit extends Cubit<VenueState> {
  VenueCubit({required VenueRepository repository, DateTime? today})
    : _repository = repository,
      _today = today,
      super(const VenueState());

  final VenueRepository _repository;
  final DateTime? _today;

  DateTime get today {
    final now = _today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: VenueStatus.loading, clearFailure: true));
    }

    final from = state.from ?? today;
    // A month ahead by default. Wide enough to plan with, narrow enough that the
    // request is not the whole year's schedule.
    final to = state.to ?? from.add(const Duration(days: 30));

    try {
      final results = await Future.wait<Object>([
        _repository.tables(includeArchived: state.includeArchived),
        _repository.slots(
          fromDate: from,
          toDate: to,
          tableId: state.tableFilterId,
        ),
      ]);

      emit(
        state.copyWith(
          status: VenueStatus.ready,
          tables: results[0] as List<VenueTable>,
          slots: results[1] as List<VenueSlot>,
          from: from,
          to: to,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.tables.isNotEmpty
              ? VenueStatus.ready
              : VenueStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  Future<void> showArchived(bool include) async {
    if (include == state.includeArchived) return;
    emit(state.copyWith(includeArchived: include));
    await load(silent: state.tables.isNotEmpty);
  }

  Future<void> filterByTable(String? tableId) async {
    if (tableId == state.tableFilterId) return;
    emit(
      tableId == null
          ? state.copyWith(clearTableFilter: true)
          : state.copyWith(tableFilterId: tableId),
    );
    await load(silent: state.tables.isNotEmpty);
  }

  Future<void> setWindow(DateTime from, DateTime to) async {
    emit(state.copyWith(from: from, to: to));
    await load(silent: state.tables.isNotEmpty);
  }

  // --------------------------------------------------------------- tables

  /// Returns an error message to show, or null on success.
  Future<String?> saveTable(VenueTable table) async {
    return _write(table.id.isEmpty ? 'new-table' : table.id, () async {
      if (table.id.isEmpty) {
        await _repository.createTable(table);
      } else {
        await _repository.updateTable(table.id, table.toJson());
      }
    });
  }

  Future<String?> setTableActive(String id, bool active) =>
      _write(id, () => _repository.updateTable(id, {'is_active': active}));

  Future<String?> archiveTable(String id) =>
      _write(id, () => _repository.archiveTable(id));

  /// Un-archives, and does **not** switch the table back on — the API leaves
  /// that separate, and quietly making it live again would put a table back in
  /// front of customers that nobody said was ready.
  Future<String?> restoreTable(String id) =>
      _write(id, () => _repository.restoreTable(id));

  // ---------------------------------------------------------------- slots

  Future<String?> createSlot({
    required String tableId,
    required DateTime serviceDate,
    required String startTime,
    required int durationMinutes,
    required int bufferMinutes,
    int? pricePence,
    String? notes,
  }) => _write('new-slot', () async {
    await _repository.createSlot(
      tableId: tableId,
      serviceDate: serviceDate,
      startTime: startTime,
      durationMinutes: durationMinutes,
      bufferMinutes: bufferMinutes,
      pricePence: pricePence,
      notes: notes,
    );
  });

  /// Opens or closes a sitting for sale.
  ///
  /// The only change a *held* slot accepts. See the class note.
  Future<String?> setSlotActive(String id, bool active) =>
      _write(id, () => _repository.updateSlot(id, {'is_active': active}));

  Future<String?> retimeSlot(
    String id, {
    required int durationMinutes,
    required int bufferMinutes,
  }) => _write(
    id,
    () => _repository.updateSlot(id, {
      'duration_minutes': durationMinutes,
      'buffer_minutes': bufferMinutes,
    }),
  );

  Future<String?> deleteSlot(String id) =>
      _write(id, () => _repository.deleteSlot(id));

  /// Bulk generation. Returns the result, or null when it failed.
  Future<(SlotGenerateResult?, String?)> generate({
    required DateTime fromDate,
    required DateTime toDate,
    required String firstSitting,
    required String lastSitting,
    required int turnMinutes,
    required int bufferMinutes,
    List<String> tableIds = const [],
    List<SlotWeekday> weekdays = const [],
    int? pricePence,
  }) async {
    emit(state.copyWith(busyIds: {...state.busyIds, 'generate'}));
    try {
      final result = await _repository.generateSlots(
        fromDate: fromDate,
        toDate: toDate,
        firstSitting: firstSitting,
        lastSitting: lastSitting,
        turnMinutes: turnMinutes,
        bufferMinutes: bufferMinutes,
        tableIds: tableIds,
        weekdays: weekdays,
        pricePence: pricePence,
      );
      emit(state.copyWith(busyIds: {...state.busyIds}..remove('generate')));
      await load(silent: true);
      return (result, null);
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove('generate')));
      return (null, failure.message);
    }
  }

  /// Runs a write, keeping the busy set and the reload in one place.
  Future<String?> _write(String id, Future<void> Function() action) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      await action();
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      // Re-read rather than patched locally: a table's seats affect which
      // parties fit it, and a slot's timing affects what overlaps.
      await load(silent: true);
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      return failure.message;
    }
  }
}
