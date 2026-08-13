import 'package:equatable/equatable.dart';

/// An order's state, exactly as the API names them.
///
/// Seven values, and [unknown] for an eighth the backend might add — the
/// integration guide is explicit that an older app must not crash on a status it
/// has never heard of, and that the raw value should survive for logging.
enum OrderStatus {
  placed('placed', 'Placed', 'Order received'),
  preparing('preparing', 'Preparing', 'Being prepared'),
  ready('ready', 'Ready', 'Ready'),
  outForDelivery('out_for_delivery', 'Out for delivery', 'On its way'),
  completed('completed', 'Completed', 'Completed'),
  cancelled('cancelled', 'Cancelled', 'Cancelled'),
  rejected('rejected', 'Rejected', 'Rejected by the restaurant'),
  unknown('', 'Unknown', 'Unknown');

  const OrderStatus(this.wire, this.label, this.customerLabel);

  /// What the API calls it. Empty for [unknown], which is never sent.
  final String wire;

  /// What staff see.
  final String label;

  /// What a customer would see. Kept here so the two vocabularies cannot drift.
  final String customerLabel;

  static OrderStatus fromApi(String? raw) {
    final value = raw?.trim().toLowerCase();
    for (final status in values) {
      if (status != unknown && status.wire == value) return status;
    }
    return unknown;
  }

  /// Nothing moves out of these.
  bool get isFinal =>
      this == completed || this == cancelled || this == rejected;

  /// Still in the kitchen's hands — what `open_only=true` returns.
  bool get isOpen => !isFinal && this != unknown;
}

/// Whether an order is collected or delivered.
///
/// It decides the legal path: only a delivery order passes through
/// `out_for_delivery`, and only a collection order completes straight from
/// `ready`.
enum FulfilmentType {
  delivery('delivery', 'Delivery'),
  collection('collection', 'Collection');

  const FulfilmentType(this.wire, this.label);

  final String wire;
  final String label;

  static FulfilmentType fromApi(String? raw) =>
      raw?.trim().toLowerCase() == 'collection' ? collection : delivery;
}

/// Cash only for now — the API rejects `card` with `CARD_PAYMENT_UNAVAILABLE`.
enum PaymentStatus {
  pending('pending', 'Unpaid'),
  paid('paid', 'Paid'),
  refunded('refunded', 'Refunded');

  const PaymentStatus(this.wire, this.label);

  final String wire;
  final String label;

  static PaymentStatus fromApi(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'paid' => paid,
        'refunded' => refunded,
        _ => pending,
      };
}

/// The documented state machine.
///
/// Kept in one place, and derived rather than hardcoded per screen: a button
/// that offers an illegal move is a 409 waiting to happen, and the guide says
/// plainly to show only the next valid action for the fulfilment type.
///
///   collection: placed → preparing → ready → completed
///   delivery:   placed → preparing → ready → out_for_delivery → completed
///
/// `rejected` and `cancelled` are available while `placed`; `cancelled` also
/// while `preparing`.
abstract final class OrderTransitions {
  static List<OrderStatus> nextFor(OrderStatus status, FulfilmentType type) =>
      switch (status) {
        OrderStatus.placed => [
          OrderStatus.preparing,
          OrderStatus.rejected,
          OrderStatus.cancelled,
        ],
        OrderStatus.preparing => [OrderStatus.ready, OrderStatus.cancelled],
        OrderStatus.ready => [
          // The one place the two paths differ. Collection cannot enter
          // out_for_delivery, and delivery cannot complete straight from ready.
          if (type == FulfilmentType.delivery)
            OrderStatus.outForDelivery
          else
            OrderStatus.completed,
        ],
        OrderStatus.outForDelivery => [OrderStatus.completed],
        _ => const [],
      };

  /// The move a busy kitchen wants on one tap: the next step along the path,
  /// ignoring the ways out.
  static OrderStatus? advanceFrom(OrderStatus status, FulfilmentType type) {
    final next = nextFor(status, type);
    return next.isEmpty ? null : next.first;
  }

  /// Whether [next] is a legal move, so a stale screen cannot send one.
  static bool allows(OrderStatus from, OrderStatus next, FulfilmentType type) =>
      nextFor(from, type).contains(next);
}

/// One line of an order, as the kitchen reads it.
class AdminOrderLine extends Equatable {
  const AdminOrderLine({
    required this.name,
    required this.quantity,
    required this.linePence,
    this.notes,
  });

  factory AdminOrderLine.fromJson(Map<String, dynamic> json) => AdminOrderLine(
    // A snapshot taken at purchase, not a join to the menu — a dish can be
    // renamed or deleted and an old ticket must still say what was bought.
    name: json['name']?.toString() ?? 'Item',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    linePence: (json['line_total_pence'] as num?)?.toInt() ?? 0,
    notes: (json['notes']?.toString().trim().isEmpty ?? true)
        ? null
        : json['notes'].toString().trim(),
  );

  final String name;
  final int quantity;
  final int linePence;

  /// What the customer asked for on this line. The kitchen needs it.
  final String? notes;

  @override
  List<Object?> get props => [name, quantity, linePence, notes];
}

/// An order in the staff queue.
///
/// Built from `OrderSummary` for a list row and `OrderAdmin` for the detail, so
/// [lines] is empty until the order has been fetched in full — the list endpoint
/// deliberately sends `item_count` instead.
class AdminOrder extends Equatable {
  const AdminOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.fulfilment,
    required this.paymentStatus,
    required this.totalPence,
    required this.itemCount,
    required this.isAsap,
    this.placedAt,
    this.requestedFor,
    this.lines = const [],
    this.contactName,
    this.contactPhone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.postcode,
    this.deliveryNotes,
    this.customerNote,
    this.cancellationReason,
    this.rawStatus,
  });

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final lines = json['items'];
    return AdminOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      status: OrderStatus.fromApi(json['status']?.toString()),
      // Preserved for logging, as the guide asks: a status the app does not know
      // still has to be reportable.
      rawStatus: json['status']?.toString(),
      fulfilment: FulfilmentType.fromApi(json['fulfilment_type']?.toString()),
      paymentStatus: PaymentStatus.fromApi(json['payment_status']?.toString()),
      totalPence: (json['total_pence'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      isAsap: json['is_asap'] != false,
      placedAt: _date(json['placed_at']),
      requestedFor: _date(json['requested_for']),
      lines: lines is List
          ? lines
                .whereType<Map>()
                .map(
                  (l) => AdminOrderLine.fromJson(Map<String, dynamic>.from(l)),
                )
                .toList()
          : const [],
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      addressLine1: json['address_line1']?.toString(),
      addressLine2: json['address_line2']?.toString(),
      city: json['city']?.toString(),
      postcode: json['postcode']?.toString(),
      deliveryNotes: json['delivery_notes']?.toString(),
      customerNote: json['customer_note']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
    );
  }

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String? rawStatus;
  final FulfilmentType fulfilment;
  final PaymentStatus paymentStatus;
  final int totalPence;
  final int itemCount;
  final bool isAsap;
  final DateTime? placedAt;

  /// When the customer asked for it. Null for an ASAP order.
  final DateTime? requestedFor;

  /// Empty on a list row — see the class note.
  final List<AdminOrderLine> lines;

  final String? contactName;
  final String? contactPhone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? postcode;
  final String? deliveryNotes;
  final String? customerNote;
  final String? cancellationReason;

  bool get hasLines => lines.isNotEmpty;

  /// Integer pence formatted without touching floating point, as the guide
  /// specifies — money in doubles is how a total ends up a penny out.
  String get formattedTotal {
    final pounds = totalPence ~/ 100;
    final pennies = (totalPence % 100).toString().padLeft(2, '0');
    return '£$pounds.$pennies';
  }

  /// The address on one line, for a delivery ticket.
  String? get address {
    if (fulfilment != FulfilmentType.delivery) return null;
    final parts = [
      addressLine1,
      addressLine2,
      city,
      postcode,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }

  List<OrderStatus> get nextStatuses =>
      OrderTransitions.nextFor(status, fulfilment);

  OrderStatus? get advanceTo =>
      OrderTransitions.advanceFrom(status, fulfilment);

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    status,
    fulfilment,
    paymentStatus,
    totalPence,
    itemCount,
    isAsap,
    placedAt,
    requestedFor,
    lines,
    contactName,
    contactPhone,
    addressLine1,
    addressLine2,
    city,
    postcode,
    deliveryNotes,
    customerNote,
    cancellationReason,
  ];
}

/// The dashboard counters from `/admin/orders/stats`.
class OrderStats extends Equatable {
  const OrderStats({
    this.openOrders = 0,
    this.placed = 0,
    this.preparing = 0,
    this.ready = 0,
    this.outForDelivery = 0,
    this.completedToday = 0,
    this.revenueTodayPence = 0,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) => OrderStats(
    openOrders: (json['open_orders'] as num?)?.toInt() ?? 0,
    placed: (json['placed'] as num?)?.toInt() ?? 0,
    preparing: (json['preparing'] as num?)?.toInt() ?? 0,
    ready: (json['ready'] as num?)?.toInt() ?? 0,
    outForDelivery: (json['out_for_delivery'] as num?)?.toInt() ?? 0,
    completedToday: (json['completed_today'] as num?)?.toInt() ?? 0,
    revenueTodayPence: (json['revenue_today_pence'] as num?)?.toInt() ?? 0,
  );

  final int openOrders;
  final int placed;
  final int preparing;
  final int ready;
  final int outForDelivery;
  final int completedToday;
  final int revenueTodayPence;

  String get formattedRevenue {
    final pounds = revenueTodayPence ~/ 100;
    final pennies = (revenueTodayPence % 100).toString().padLeft(2, '0');
    return '£$pounds.$pennies';
  }

  @override
  List<Object?> get props => [
    openOrders,
    placed,
    preparing,
    ready,
    outForDelivery,
    completedToday,
    revenueTodayPence,
  ];
}
