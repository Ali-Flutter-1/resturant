import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/orders/domain/customer_order.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/orders/domain/order_quote.dart';
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

  /// What a quote answers with. Set by a test that cares.
  ///
  /// The slots are relative to now, not fixed dates. They used to be pinned to
  /// 2026-08-12, which meant the screen labelled them "Today" only while the
  /// calendar agreed — the timing tests passed on the day they were written and
  /// silently started failing afterwards.
  OrderQuote quoteResult = OrderQuote(
    subtotalPence: 1790,
    deliveryFeePence: 299,
    totalPence: 2089,
    minimumOrderPence: 1000,
    availableSlots: [
      slotIn(const Duration(hours: 2)),
      slotIn(const Duration(hours: 2, minutes: 15)),
    ],
  );

  /// An ISO slot [ahead] from now, with an offset, exactly as the API sends it.
  static String slotIn(Duration ahead) =>
      DateTime.now().toUtc().add(ahead).toIso8601String();

  /// Fails only the quote, so a test can price fine and be refused on placing.
  ApiFailure? quoteFailure;
  ApiFailure? placeFailure;

  int quoteCalls = 0;
  int placeCalls = 0;
  bool? lastQuoteDelivery;

  /// Every key a placement was attempted with, in order. The interesting
  /// assertion is that a retry reuses the first one.
  final idempotencyKeys = <String>[];
  Map<String, Object?>? lastPlaced;

  @override
  Future<OrderQuote> quote({
    required bool isDelivery,
    required List<CartLine> lines,
  }) async {
    quoteCalls++;
    lastQuoteDelivery = isDelivery;
    final error = quoteFailure ?? failure;
    if (error != null) throw error;
    return quoteResult;
  }

  @override
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
  }) async {
    placeCalls++;
    idempotencyKeys.add(idempotencyKey);
    lastPlaced = {
      'is_delivery': isDelivery,
      'items': [for (final line in lines) line.toJson()],
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'is_asap': isAsap,
      'requested_for': requestedFor,
      'address_line1': addressLine1,
      'city': city,
      'postcode': postcode,
      'customer_note': customerNote,
    };

    final error = placeFailure ?? failure;
    if (error != null) throw error;

    final placed = CustomerOrder(
      id: 'new-order',
      reference: 'AB12-CD34',
      status: CustomerOrderStatus.placed,
      totalPence: quoteResult.totalPence,
      placedAt: DateTime(2026, 8, 12, 18, 30),
      isDelivery: isDelivery,
      canCancel: true,
    );
    orders = [placed, ...orders];
    return placed;
  }

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
    bool wasRejected = false,
    String? cancellationReason,
  }) => CustomerOrder(
    id: id,
    reference: reference,
    status: status,
    totalPence: totalPence,
    wasRejected: wasRejected,
    cancellationReason: cancellationReason,
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
