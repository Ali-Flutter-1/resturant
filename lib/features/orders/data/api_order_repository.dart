import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/customer_order.dart';
import '../domain/order_repository.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<CustomerOrder>> myOrders() async {
    final rows = await _client.list(ApiConstants.orders);
    final orders = rows.map(CustomerOrder.fromJson).toList();
    // Sorted here rather than trusted from the API. The list endpoint is
    // paginated and its default ordering isn't documented, and this screen's
    // whole shape — live order on top, history beneath — depends on newest
    // first. Orders with no timestamp sink rather than jumping the queue.
    orders.sort((a, b) {
      final at = a.placedAt, bt = b.placedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return orders;
  }

  @override
  Future<CustomerOrder> orderById(String id) async =>
      CustomerOrder.fromJson(await _client.object(ApiConstants.order(id)));

  @override
  Future<CustomerOrder> cancel(String id) async => CustomerOrder.fromJson(
    await _client.object(ApiConstants.orderCancel(id), method: 'POST'),
  );
}
