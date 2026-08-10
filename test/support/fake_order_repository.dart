import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/orders/domain/customer_order.dart';
import 'package:practice/features/orders/domain/order_repository.dart';

/// An [OrderRepository] that answers from memory.
///
/// [failure] makes every call fail, so the error and retry paths can be driven
/// without a network. [cancelFailure] fails only the cancellation, which is the
/// case that matters most: cancelling races the kitchen, so the screen must
/// handle a refusal.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({
    List<CustomerOrder>? orders,
    this.failure,
    this.cancelFailure,
  }) : orders = orders ?? [];

  List<CustomerOrder> orders;
  ApiFailure? failure;
  ApiFailure? cancelFailure;

  int loadCount = 0;
  final cancelled = <String>[];

  @override
  Future<List<CustomerOrder>> myOrders() async {
    loadCount++;
    if (failure != null) throw failure!;
    return orders;
  }

  @override
  Future<CustomerOrder> orderById(String id) async {
    if (failure != null) throw failure!;
    return orders.firstWhere((order) => order.id == id);
  }

  @override
  Future<CustomerOrder> cancel(String id) async {
    if (cancelFailure != null) throw cancelFailure!;
    cancelled.add(id);
    final order = orders.firstWhere((o) => o.id == id);
    final updated = OrderFixtures.copyCancelled(order);
    orders = [
      for (final o in orders)
        if (o.id == id) updated else o,
    ];
    return updated;
  }
}

/// Orders to build screens from.
abstract final class OrderFixtures {
  static CustomerOrder order({
    String id = 'order-1',
    String reference = '#0042',
    CustomerOrderStatus status = CustomerOrderStatus.preparing,
    int totalPence = 2850,
    DateTime? placedAt,
    List<CustomerOrderItem> items = const [
      CustomerOrderItem(dishName: 'Jaffna Crab', quantity: 1, linePence: 1850),
      CustomerOrderItem(dishName: 'Hoppers', quantity: 2, linePence: 1000),
    ],
    bool isDelivery = true,
    bool canCancel = false,
  }) => CustomerOrder(
    id: id,
    reference: reference,
    status: status,
    totalPence: totalPence,
    // Fixed rather than `DateTime.now()`: a test that formats a date should not
    // change its answer at midnight.
    placedAt: placedAt ?? DateTime(2026, 8, 1, 19, 30),
    items: items,
    isDelivery: isDelivery,
    canCancel: canCancel,
  );

  static CustomerOrder copyCancelled(CustomerOrder order) => CustomerOrder(
    id: order.id,
    reference: order.reference,
    status: CustomerOrderStatus.cancelled,
    totalPence: order.totalPence,
    placedAt: order.placedAt,
    items: order.items,
    isDelivery: order.isDelivery,
  );
}
