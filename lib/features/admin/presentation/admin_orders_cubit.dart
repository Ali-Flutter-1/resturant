import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/admin_order.dart';
import '../domain/admin_order_repository.dart';

enum QueueStatus { loading, ready, failure }

class AdminOrdersState extends Equatable {
  const AdminOrdersState({
    this.status = QueueStatus.loading,
    this.orders = const [],
    this.stats = const OrderStats(),
    this.failure,
    this.filter,
    this.openOnly = true,
    this.query = '',
    this.busyIds = const {},
    this.detail,
  });

  final QueueStatus status;

  /// Newest first, as the API returns them.
  final List<AdminOrder> orders;

  final OrderStats stats;
  final ApiFailure? failure;

  /// Null means every state the current [openOnly] allows.
  final OrderStatus? filter;

  /// The kitchen queue by default: completed, cancelled and rejected orders are
  /// noise on a screen whose job is "what do we cook next".
  final bool openOnly;

  /// Client-side search. `/admin/orders` has no search parameter, so this
  /// narrows what is loaded rather than the whole history.
  final String query;

  /// Orders with a status change in flight, so only that row is disabled.
  final Set<String> busyIds;

  /// The order open in the detail sheet, held **outside** [orders].
  ///
  /// The sheet used to look its order up in the list, which meant the 20-second
  /// poll wiped it: `load` replaces the list wholesale, and an order the current
  /// filter no longer returns — a completed one, or anything past the first page
  /// — simply vanished from under the reader. Keeping it here makes the sheet
  /// independent of whatever the queue is showing.
  final AdminOrder? detail;

  List<AdminOrder> get visible {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return orders;
    return orders.where((order) {
      return order.orderNumber.toLowerCase().contains(needle) ||
          (order.contactName?.toLowerCase().contains(needle) ?? false) ||
          (order.contactPhone?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  bool get isSearchEmpty =>
      status == QueueStatus.ready && orders.isNotEmpty && visible.isEmpty;

  AdminOrdersState copyWith({
    QueueStatus? status,
    List<AdminOrder>? orders,
    OrderStats? stats,
    ApiFailure? failure,
    OrderStatus? filter,
    bool? openOnly,
    String? query,
    Set<String>? busyIds,
    AdminOrder? detail,
    bool clearFilter = false,
    bool clearFailure = false,
    bool clearDetail = false,
  }) {
    return AdminOrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      stats: stats ?? this.stats,
      failure: clearFailure ? null : (failure ?? this.failure),
      filter: clearFilter ? null : (filter ?? this.filter),
      openOnly: openOnly ?? this.openOnly,
      query: query ?? this.query,
      busyIds: busyIds ?? this.busyIds,
      detail: clearDetail ? null : (detail ?? this.detail),
    );
  }

  @override
  List<Object?> get props => [
    status,
    orders,
    stats,
    failure,
    filter,
    openOnly,
    query,
    busyIds,
    detail,
  ];
}

/// The kitchen queue.
///
/// Two rules from the integration guide shape this class:
///
///  * **Never move a status optimistically.** Another member of staff may have
///    changed the order a second ago, so the screen adopts what the server
///    returned. A row that flipped to "Ready" locally and then failed would have
///    the kitchen believing food was on the counter.
///  * **On a refused transition, reload the order.** `INVALID_STATUS_TRANSITION`
///    and `ORDER_STATUS_UNCHANGED` both mean this screen is out of date, so the
///    fix is to re-read that order rather than to show an error and leave the
///    stale row in place.
class AdminOrdersCubit extends Cubit<AdminOrdersState> {
  AdminOrdersCubit({required AdminOrderRepository repository})
    : _repository = repository,
      super(const AdminOrdersState());

  final AdminOrderRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: QueueStatus.loading, clearFailure: true));
    }

    try {
      // Together: the tiles and the list are the same screen, and two requests
      // in sequence would show a queue above stale counters.
      final results = await Future.wait([
        _repository.orders(
          status: state.filter,
          openOnly: state.openOnly && state.filter == null,
          pageSize: 50,
        ),
        _repository.stats(),
      ]);

      emit(
        state.copyWith(
          status: QueueStatus.ready,
          orders: results[0] as List<AdminOrder>,
          stats: results[1] as OrderStats,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.orders.isNotEmpty
              ? QueueStatus.ready
              : QueueStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  /// Narrows to one status, or clears it.
  ///
  /// Refetched rather than filtered locally: the queue is paginated, so a
  /// filtered view built from the loaded page would be missing orders.
  Future<void> filterBy(OrderStatus? status) async {
    emit(
      status == null
          ? state.copyWith(clearFilter: true)
          : state.copyWith(filter: status),
    );
    await load(silent: state.orders.isNotEmpty);
  }

  /// Switches between the kitchen queue and the full history.
  Future<void> showOpenOnly(bool value) async {
    emit(state.copyWith(openOnly: value, clearFilter: true));
    await load(silent: state.orders.isNotEmpty);
  }

  /// Moves one order along.
  ///
  /// Returns an error message to show, or null on success. Refuses locally when
  /// the move is not legal for that order's fulfilment type — a request the API
  /// would answer with a 409 is one worth not making.
  Future<String?> changeStatus(
    String id,
    OrderStatus next, {
    String? note,
  }) async {
    if (state.busyIds.contains(id)) return null;

    final current = state.orders.where((o) => o.id == id).firstOrNull;
    if (current != null &&
        !OrderTransitions.allows(current.status, next, current.fulfilment)) {
      return '${current.status.label} cannot move straight to '
          '${next.label.toLowerCase()}.';
    }

    emit(state.copyWith(busyIds: {...state.busyIds, id}));
    try {
      final updated = await _repository.updateStatus(
        id,
        status: next,
        note: note,
      );
      _adopt(updated, dropIfClosed: state.openOnly && state.filter == null);
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      // The tiles moved too — a completed order changes the day's revenue.
      await _refreshStats();
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));

      // A conflict means somebody else got there first, so this screen is the
      // thing that is wrong. Re-read the order rather than arguing with it.
      if (failure.kind == ApiFailureKind.conflict) {
        await refreshOne(id);
      }
      return failure.message;
    }
  }

  /// Opens the detail sheet on [order], then fetches the full ticket.
  ///
  /// Seeded from the row so the sheet has something to draw immediately — the
  /// list carries `item_count` rather than lines, so the fetch is what fills in
  /// the breakdown.
  Future<void> openDetail(AdminOrder order) async {
    emit(state.copyWith(detail: order));
    await refreshOne(order.id);
  }

  void closeDetail() => emit(state.copyWith(clearDetail: true));

  /// Re-reads one order, for a stale row or an opened detail sheet.
  Future<AdminOrder?> refreshOne(String id) async {
    try {
      final order = await _repository.orderById(id);
      _adopt(order);
      return order;
    } on ApiFailure {
      return null;
    }
  }

  void _adopt(AdminOrder order, {bool dropIfClosed = false}) {
    // The sheet reads `detail`, so every write has to land there too — otherwise
    // advancing an order leaves the ticket showing its previous status.
    if (state.detail?.id == order.id) {
      emit(state.copyWith(detail: order));
    }
    // An order that has just been completed or cancelled leaves the kitchen
    // queue, because that is what the queue means. On the full history it stays,
    // with its new status.
    if (dropIfClosed && order.status.isFinal) {
      emit(
        state.copyWith(
          orders: [
            for (final existing in state.orders)
              if (existing.id != order.id) existing,
          ],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        orders: [
          for (final existing in state.orders)
            if (existing.id == order.id) order else existing,
        ],
      ),
    );
  }

  Future<void> _refreshStats() async {
    try {
      emit(state.copyWith(stats: await _repository.stats()));
    } on ApiFailure {
      // The counters being a moment stale is not worth an error on a screen
      // whose main job just succeeded.
    }
  }
}
