import '../../cart/cart_cubit.dart';
import 'customer_order.dart';
import 'order_quote.dart';

/// The signed-in customer's own orders.
///
/// Nothing here takes a user id: every endpoint is scoped to the bearer token,
/// so there is no way for this interface to ask for somebody else's history.
abstract interface class OrderRepository {
  /// Prices a basket without creating anything.
  ///
  /// Called when checkout opens and again whenever the basket or the fulfilment
  /// type changes — the returned totals are what the screen renders, and the
  /// slots are what a scheduled order must choose from.
  Future<OrderQuote> quote({
    required bool isDelivery,
    required List<CartLine> lines,
  });

  /// Places the order.
  ///
  /// [idempotencyKey] must be generated once per checkout and **reused** on
  /// every retry of that same checkout, including after a timeout — a fresh key
  /// on retry is how a customer ends up with two orders.
  Future<CustomerOrder> place({
    required String idempotencyKey,
    required bool isDelivery,
    required List<CartLine> lines,
    required String contactName,
    required String contactPhone,
    bool isAsap = true,
    String? requestedFor,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? postcode,
    String? deliveryNotes,
    String? customerNote,
  });

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
