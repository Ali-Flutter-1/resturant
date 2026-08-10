import 'customer_order.dart';

/// The signed-in customer's own orders.
///
/// Nothing here takes a user id: every endpoint is scoped to the bearer token,
/// so there is no way for this interface to ask for somebody else's history.
abstract interface class OrderRepository {
  /// Newest first.
  Future<List<CustomerOrder>> myOrders();

  /// One order in full, including its lines.
  Future<CustomerOrder> orderById(String id);

  /// Cancels an order the kitchen hasn't started.
  ///
  /// Returns the updated order so the screen shows the server's verdict rather
  /// than assuming the cancellation stuck.
  Future<CustomerOrder> cancel(String id);
}
