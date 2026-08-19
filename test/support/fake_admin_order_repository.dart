import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/admin/domain/admin_order.dart';
import 'package:practice/features/admin/domain/admin_order_repository.dart';

/// The kitchen queue, in memory.
///
/// Returns copies rather than its own list: handing out a reference lets a write
/// mutate the list already held in cubit state, which makes Equatable see no
/// change and turns `emit` into a no-op.
class FakeAdminOrderRepository implements AdminOrderRepository {
  FakeAdminOrderRepository({List<AdminOrder>? orders, this.delay})
    : _orders = orders ?? [...defaults];

  /// Holds the answer, so a test can observe the loading state.
  final Duration? delay;

  static final defaults = <AdminOrder>[
    AdminOrder(
      id: 'o1',
      orderNumber: 'AB12-CD34',
      status: OrderStatus.placed,
      fulfilment: FulfilmentType.delivery,
      paymentStatus: PaymentStatus.pending,
      totalPence: 2089,
      itemCount: 2,
      isAsap: true,
      placedAt: DateTime(2026, 8, 12, 18, 30),
      contactName: 'Ali Hassan',
      contactPhone: '07700 900123',
      addressLine1: '12 Example Street',
      city: 'Manchester',
      postcode: 'M1 2AB',
      lines: const [
        AdminOrderLine(
          name: 'Chicken Kottu',
          quantity: 2,
          linePence: 1790,
          notes: 'No coriander',
        ),
      ],
    ),
    AdminOrder(
      id: 'o2',
      orderNumber: 'EF56-GH78',
      status: OrderStatus.ready,
      fulfilment: FulfilmentType.collection,
      paymentStatus: PaymentStatus.pending,
      totalPence: 895,
      itemCount: 1,
      isAsap: true,
      placedAt: DateTime(2026, 8, 12, 18, 5),
      contactName: 'Priya Raj',
      contactPhone: '07700 900456',
    ),
  ];

  List<AdminOrder> _orders;

  /// Replaces what the list endpoint answers with, so a test can simulate an
  /// order leaving the filtered queue between polls.
  void replaceListWith(List<AdminOrder> value) => _orders = List.of(value);

  ApiFailure? failure;

  /// Fails only the status write, so a test can load fine and be refused on the
  /// move — which is the interesting case.
  ApiFailure? statusFailure;

  int listCalls = 0;
  int statsCalls = 0;
  OrderStatus? lastFilter;
  bool? lastOpenOnly;
  Map<String, Object?>? lastStatusChange;
  OrderStats stats0 = const OrderStats(
    openOrders: 2,
    placed: 1,
    ready: 1,
    completedToday: 3,
    revenueTodayPence: 4560,
  );

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<AdminOrder>> orders({
    int page = 1,
    int pageSize = 20,
    OrderStatus? status,
    FulfilmentType? fulfilment,
    bool openOnly = false,
  }) async {
    listCalls++;
    lastFilter = status;
    lastOpenOnly = openOnly;
    await _wait();
    _check();

    var rows = List.of(_orders);
    if (status != null) {
      rows = rows.where((o) => o.status == status).toList();
    } else if (openOnly) {
      rows = rows.where((o) => o.status.isOpen).toList();
    }
    return rows;
  }

  @override
  Future<OrderStats> stats() async {
    statsCalls++;
    await _wait();
    _check();
    return stats0;
  }

  @override
  Future<AdminOrder> orderById(String id) async {
    await _wait();
    _check();
    return _orders.firstWhere((o) => o.id == id);
  }

  @override
  Future<AdminOrder> updateStatus(
    String id, {
    required OrderStatus status,
    String? note,
  }) async {
    await _wait();
    final error = statusFailure ?? failure;
    if (error != null) throw error;

    lastStatusChange = {'id': id, 'status': status.wire, 'note': note};
    final existing = _orders.firstWhere((o) => o.id == id);
    final updated = AdminOrder(
      id: existing.id,
      orderNumber: existing.orderNumber,
      status: status,
      fulfilment: existing.fulfilment,
      paymentStatus: existing.paymentStatus,
      totalPence: existing.totalPence,
      itemCount: existing.itemCount,
      isAsap: existing.isAsap,
      placedAt: existing.placedAt,
      requestedFor: existing.requestedFor,
      lines: existing.lines,
      contactName: existing.contactName,
      contactPhone: existing.contactPhone,
      addressLine1: existing.addressLine1,
      city: existing.city,
      postcode: existing.postcode,
      cancellationReason: note,
    );
    _orders = [
      for (final o in _orders)
        if (o.id == id) updated else o,
    ];
    return updated;
  }
}
