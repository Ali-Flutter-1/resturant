import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/admin_order.dart';
import '../domain/admin_order_repository.dart';

class ApiAdminOrderRepository implements AdminOrderRepository {
  ApiAdminOrderRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<AdminOrder>> orders({
    int page = 1,
    int pageSize = 20,
    OrderStatus? status,
    FulfilmentType? fulfilment,
    bool openOnly = false,
  }) async {
    final rows = await _client.list(
      ApiConstants.adminOrders,
      query: {
        'page': page,
        'page_size': pageSize,
        // Omitted rather than sent empty: an absent filter and a filter for
        // nothing are different requests.
        'status': ?status?.wire,
        'fulfilment_type': ?fulfilment?.wire,
        if (openOnly) 'open_only': true,
      },
    );
    return rows.map(AdminOrder.fromJson).toList();
  }

  @override
  Future<OrderStats> stats() async =>
      OrderStats.fromJson(await _client.object(ApiConstants.adminOrderStats));

  @override
  Future<AdminOrder> orderById(String id) async =>
      AdminOrder.fromJson(await _client.object(ApiConstants.adminOrder(id)));

  @override
  Future<AdminOrder> updateStatus(
    String id, {
    required OrderStatus status,
    String? note,
  }) async {
    final data = await _client.object(
      ApiConstants.adminOrderStatus(id),
      method: 'PATCH',
      body: {
        'status': status.wire,
        'note': ?(note?.trim().isEmpty ?? true) ? null : note!.trim(),
      },
    );
    return AdminOrder.fromJson(data);
  }
}
