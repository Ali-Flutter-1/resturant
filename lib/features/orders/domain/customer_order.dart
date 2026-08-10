import 'package:equatable/equatable.dart';

/// Where an order has got to, as the customer needs to understand it.
///
/// Deliberately separate from the `OrderStatus` the staff screens use. That one
/// is the kitchen's vocabulary — including `overdue`, which exists so staff can
/// see a queue slipping. Telling a customer their food is "overdue" would be a
/// worse experience than saying nothing, so this enum has no such value and the
/// mapping below folds it into the state the customer can act on.
///
/// [fromApi] is tolerant on purpose. A status the app has never heard of maps to
/// [placed] rather than throwing: an unknown value means the backend gained a
/// state, and the right response is to show the order as in progress, not to
/// fail the whole history screen because one row is newer than the app.
enum CustomerOrderStatus {
  placed('Order placed', 'We have your order and the kitchen has been told.'),
  preparing('Being prepared', 'The kitchen is cooking your food now.'),
  ready('Ready', 'Your order is ready and waiting for you.'),
  outForDelivery(
    'On its way',
    'Your rider has your order and is heading over.',
  ),
  completed('Completed', 'Delivered and done. Thanks for ordering.'),
  cancelled('Cancelled', 'This order was cancelled.');

  const CustomerOrderStatus(this.label, this.explanation);

  /// The short form, for a pill.
  final String label;

  /// A sentence for the tracker card, where there is room to be reassuring.
  final String explanation;

  static CustomerOrderStatus fromApi(String? raw) => switch (raw
      ?.trim()
      .toLowerCase()) {
    'placed' || 'pending' || 'confirmed' || 'accepted' => placed,
    'preparing' || 'in_progress' || 'cooking' => preparing,
    'ready' || 'ready_for_collection' || 'ready_for_pickup' => ready,
    'out_for_delivery' || 'delivering' || 'dispatched' => outForDelivery,
    'completed' ||
    'served' ||
    'collected' ||
    'delivered' ||
    'fulfilled' => completed,
    'cancelled' || 'canceled' || 'rejected' || 'refunded' => cancelled,
    // Includes null and the kitchen-only `overdue`: a late order is still an
    // order being worked on, which is all the customer can do anything with.
    _ => placed,
  };

  /// Whether this order is still happening, and so belongs at the top of the
  /// screen rather than in the history list.
  bool get isLive => switch (this) {
    placed || preparing || ready || outForDelivery => true,
    completed || cancelled => false,
  };

  /// Position along the progress bar, or null for orders that never finish it.
  ///
  /// Cancelled has no place on a track that only moves forwards, and drawing it
  /// at step zero would suggest it was about to start again.
  int? get step => switch (this) {
    placed => 0,
    preparing => 1,
    ready || outForDelivery => 2,
    completed => 3,
    cancelled => null,
  };

  /// How many stops the tracker draws.
  static const int steps = 4;
}

/// One line of an order.
///
/// The name is stored rather than looked up from the menu: a dish can be
/// renamed or withdrawn, and an old receipt should keep saying what was
/// actually bought.
class CustomerOrderItem extends Equatable {
  const CustomerOrderItem({
    required this.dishName,
    required this.quantity,
    required this.linePence,
    this.notes,
  });

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    // Prefer the server's line total. Falling back to unit × quantity is only
    // for endpoints that send the unit price alone — never recomputed when the
    // server has already done the arithmetic, because the server is the one
    // that has to match the payment.
    final line = (json['line_total_pence'] ?? json['total_pence']) as num?;
    final unit = (json['unit_price_pence'] ?? json['price_pence']) as num?;

    return CustomerOrderItem(
      dishName:
          json['dish_name']?.toString() ??
          (json['dish'] is Map
              ? (json['dish'] as Map)['name']?.toString() ?? 'Item'
              : 'Item'),
      quantity: quantity,
      linePence: line?.toInt() ?? ((unit?.toInt() ?? 0) * quantity),
      notes: (json['notes']?.toString().trim().isEmpty ?? true)
          ? null
          : json['notes'].toString().trim(),
    );
  }

  final String dishName;
  final int quantity;
  final int linePence;
  final String? notes;

  @override
  List<Object?> get props => [dishName, quantity, linePence, notes];
}

/// An order as the customer's own history shows it.
class CustomerOrder extends Equatable {
  const CustomerOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.totalPence,
    required this.placedAt,
    this.items = const [],
    this.isDelivery = true,
    this.estimatedReadyAt,
    this.canCancel = false,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final id = json['id']?.toString() ?? '';
    final status = CustomerOrderStatus.fromApi(json['status']?.toString());
    final method = json['fulfilment_method'] ?? json['fulfillment_method'];

    return CustomerOrder(
      id: id,
      // The API's own reference where it sends one. The id tail is a fallback
      // rather than a decoration: a customer ringing up needs to be able to
      // read *something* back, and a bare UUID is unreadable aloud.
      reference: json['reference']?.toString() ?? _shortRef(id),
      status: status,
      totalPence: (json['total_pence'] as num?)?.toInt() ?? 0,
      placedAt: _date(json['created_at'] ?? json['placed_at']),
      items: items is List
          ? items
                .whereType<Map>()
                .map(
                  (i) =>
                      CustomerOrderItem.fromJson(Map<String, dynamic>.from(i)),
                )
                .toList()
          : const [],
      isDelivery: method?.toString().toLowerCase() != 'collection',
      estimatedReadyAt: _date(json['estimated_ready_at'] ?? json['ready_at']),
      // Trust the server's own word on this where it gives one — it knows
      // things the app can't, like whether the kitchen has already started.
      // Otherwise fall back to the documented rule: cancellable while placed.
      canCancel: json['can_cancel'] is bool
          ? json['can_cancel'] as bool
          : status == CustomerOrderStatus.placed,
    );
  }

  static String _shortRef(String id) {
    final tail = id.replaceAll('-', '');
    return tail.length <= 4
        ? '#$tail'
        : '#${tail.substring(tail.length - 4).toUpperCase()}';
  }

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  final String id;
  final String reference;
  final CustomerOrderStatus status;
  final int totalPence;

  /// Null where the server sent no timestamp — the screen then omits the "when"
  /// line rather than printing an invented date.
  final DateTime? placedAt;

  final List<CustomerOrderItem> items;

  /// False means collection. Affects wording only: a collection order is never
  /// "on its way".
  final bool isDelivery;

  final DateTime? estimatedReadyAt;

  final bool canCancel;

  String get formattedTotal => '£${(totalPence / 100).toStringAsFixed(2)}';

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// The status line, adjusted for collection orders.
  ///
  /// The shared enum can't know the fulfilment method, and "On its way" for an
  /// order the customer is walking in to collect is simply wrong.
  String get statusLabel =>
      !isDelivery && status == CustomerOrderStatus.outForDelivery
      ? 'Ready to collect'
      : status.label;

  String get statusExplanation =>
      !isDelivery && status == CustomerOrderStatus.ready
      ? 'Your order is ready to collect from the counter.'
      : status.explanation;

  @override
  List<Object?> get props => [
    id,
    reference,
    status,
    totalPence,
    placedAt,
    items,
    isDelivery,
    estimatedReadyAt,
    canCancel,
  ];
}
