import 'admin_order.dart';

/// The staff and admin order queue.
///
/// Every route here accepts both roles — the guide is explicit that staff and
/// admin have the same order permissions, and that a customer gets 403.
abstract interface class AdminOrderRepository {
  /// Newest first, paginated.
  ///
  /// [openOnly] is the kitchen queue: everything not yet completed, cancelled or
  /// rejected.
  Future<List<AdminOrder>> orders({
    int page = 1,
    int pageSize = 20,
    OrderStatus? status,
    FulfilmentType? fulfilment,
    bool openOnly = false,
  });

  Future<OrderStats> stats();

  /// One order in full, including its lines and the customer's contact details.
  Future<AdminOrder> orderById(String id);

  /// Moves an order exactly one legal step.
  ///
  /// [note] becomes the cancellation reason when the new status is `cancelled`
  /// or `rejected`. Returns the updated order so the screen shows what the
  /// server did rather than what it hoped for.
  Future<AdminOrder> updateStatus(
    String id, {
    required OrderStatus status,
    String? note,
  });
}
