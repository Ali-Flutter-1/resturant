import 'package:equatable/equatable.dart';

import '../../menu/domain/spice_level.dart';

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
    this.spiceLevel,
    this.notes,
  });

  factory CustomerOrderItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    // Prefer the server's line total. Falling back to unit × quantity is only
    // for endpoints that send the unit price alone — never recomputed when the
    // server has already done the arithmetic, because the server is the one
    // that has to match the payment.
    final line = json['line_total_pence'] as num?;
    final unit = json['unit_price_pence'] as num?;

    return CustomerOrderItem(
      // `name`, not a nested dish: the API stores the name on the line so an
      // old receipt keeps saying what was actually bought even after the dish
      // has been renamed or withdrawn.
      dishName: json['name']?.toString() ?? 'Item',
      quantity: quantity,
      linePence: line?.toInt() ?? ((unit?.toInt() ?? 0) * quantity),
      // Read from the order, never from the dish. An admin can turn spice
      // choices off later, and a receipt must keep saying what was ordered.
      spiceLevel: SpiceLevel.tryParse(json['spice_level']),
      notes: (json['notes']?.toString().trim().isEmpty ?? true)
          ? null
          : json['notes'].toString().trim(),
    );
  }

  final String dishName;
  final int quantity;
  final int linePence;
  final SpiceLevel? spiceLevel;
  final String? notes;

  @override
  List<Object?> get props => [dishName, quantity, linePence, spiceLevel, notes];
}

/// How the customer chose to pay.
enum PaymentMethod {
  cash('cash', 'Cash'),
  card('card', 'Card');

  const PaymentMethod(this.wire, this.label);

  final String wire;
  final String label;

  static PaymentMethod fromApi(String? raw) =>
      raw?.trim().toLowerCase() == 'card' ? card : cash;
}

/// Where the money has got to.
///
/// The only thing that moves an order to [paid] is Worldpay calling the
/// backend's webhook, server to server. The app never decides this -- a closed
/// payment sheet and a success-looking redirect both prove nothing.
enum CustomerPaymentStatus {
  pending('pending'),
  paid('paid'),
  failed('failed'),
  refunded('refunded');

  const CustomerPaymentStatus(this.wire);

  final String wire;

  static CustomerPaymentStatus fromApi(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'paid' => paid,
        'failed' || 'declined' || 'refused' => failed,
        'refunded' => refunded,
        _ => pending,
      };
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
    this.wasRejected = false,
    this.cancellationReason,
    this.cancelledAt,
    this.itemCountFallback,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentStatus = CustomerPaymentStatus.pending,
    this.paymentUrl,
    this.paidAt,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final id = json['id']?.toString() ?? '';
    final status = CustomerOrderStatus.fromApi(json['status']?.toString());
    final fulfilment = json['fulfilment_type']?.toString().toLowerCase();
    final raw = json['status']?.toString().trim().toLowerCase();

    return CustomerOrder(
      id: id,
      // `order_number` is the API's own human-facing reference. The id tail is
      // a fallback rather than a decoration: a customer ringing up needs to be
      // able to read *something* back, and a bare UUID is unreadable aloud.
      reference: json['order_number']?.toString() ?? _shortRef(id),
      status: status,
      totalPence: (json['total_pence'] as num?)?.toInt() ?? 0,
      placedAt: _date(json['placed_at']),
      items: items is List
          ? items
                .whereType<Map>()
                .map(
                  (i) =>
                      CustomerOrderItem.fromJson(Map<String, dynamic>.from(i)),
                )
                .toList()
          : const [],
      // Anything that isn't collection is treated as delivery. The field is a
      // free string in the spec, so matching the one value that changes the
      // wording is safer than enumerating values the backend may add.
      isDelivery: fulfilment != 'collection' && fulfilment != 'pickup',
      // `requested_for` is when the customer asked for it, and is null for an
      // ASAP order — which is exactly when there is no time worth printing.
      estimatedReadyAt: json['is_asap'] == true
          ? null
          : _date(json['requested_for']),
      // The list endpoint omits lines entirely — `item_count` is how many there
      // were, which is all a row needs.
      itemCountFallback: (json['item_count'] as num?)?.toInt(),
      // Only before cooking starts, and only if the server agrees.
      //
      // Both halves matter. The status check is the customer-facing promise:
      // once the kitchen is cooking, food and time have been spent and calling
      // it off is a conversation, not a button. The server's `can_cancel` can
      // still veto -- it knows things the app cannot -- but it can never widen
      // the window, which is why this is an AND rather than a preference for
      // whichever value the server sent.
      canCancel:
          status == CustomerOrderStatus.placed &&
          (json['can_cancel'] is bool ? json['can_cancel'] as bool : true),
      // `rejected` and `cancelled` are one state to a tracker, but not to the
      // person reading it: one is "we could not take this", the other is
      // "you or we called it off". The wording differs, so the raw value is
      // kept even though [status] folds the two together.
      wasRejected: raw == 'rejected' || raw == 'declined',
      // Set by staff when they cancel or reject — the API makes the note
      // mandatory for exactly those two, so there is always something to show.
      cancellationReason: _text(json['cancellation_reason']),
      cancelledAt: _date(json['cancelled_at']),
      paymentMethod: PaymentMethod.fromApi(json['payment_method']?.toString()),
      paymentStatus: CustomerPaymentStatus.fromApi(
        json['payment_status']?.toString(),
      ),
      // Present only while there is something to pay: the server nulls it once
      // an order is paid, and after a decline until a fresh page is asked for.
      paymentUrl: _text(json['payment_url']),
      paidAt: _date(json['paid_at']),
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

  static String? _text(Object? raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

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

  /// Whether the restaurant refused the order, as opposed to it being cancelled.
  final bool wasRejected;

  /// Why the restaurant cancelled or rejected it, in their own words.
  ///
  /// Only ever present on a cancelled or rejected order, and only from the
  /// *detail* endpoint — the paginated list sends a summary with no reason, so a
  /// row has to be opened before this can be shown.
  final String? cancellationReason;

  final DateTime? cancelledAt;

  /// `item_count` from the list endpoint, which sends no lines at all. Null on a
  /// fetched order, where [items] is authoritative.
  final int? itemCountFallback;

  final PaymentMethod paymentMethod;
  final CustomerPaymentStatus paymentStatus;

  /// Worldpay's hosted page, when there is one to open.
  final String? paymentUrl;

  final DateTime? paidAt;

  bool get isCard => paymentMethod == PaymentMethod.card;
  bool get isPaid => paymentStatus == CustomerPaymentStatus.paid;

  /// A card order the customer still owes money on.
  ///
  /// A refunded order is deliberately excluded: money moved and then moved
  /// back, and asking for it again would be asking them to pay twice.
  bool get needsPayment =>
      isCard && !isPaid && paymentStatus != CustomerPaymentStatus.refunded;

  /// A card order that has been placed but not paid has **not** reached the
  /// kitchen -- the backend holds it until the payment webhook lands -- so it
  /// must never be described as being cooked.
  bool get awaitingPayment =>
      isCard && paymentStatus == CustomerPaymentStatus.pending;

  /// Whether the lines are known, or only how many there were.
  ///
  /// The list endpoint deliberately omits them, so a row shows the count and the
  /// receipt fetches the order in full rather than displaying an empty
  /// breakdown and calling it a receipt.
  bool get hasItemDetail => items.isNotEmpty;

  String get formattedTotal => '£${(totalPence / 100).toStringAsFixed(2)}';

  int get itemCount => items.isEmpty
      ? (itemCountFallback ?? 0)
      : items.fold(0, (sum, item) => sum + item.quantity);

  /// The status line, adjusted for collection orders.
  ///
  /// The shared enum can't know the fulfilment method, and "On its way" for an
  /// order the customer is walking in to collect is simply wrong.
  String get statusLabel {
    if (wasRejected) return 'Declined';
    // An unpaid card order has not been sent to the kitchen at all, so no
    // kitchen-facing status describes it honestly.
    if (awaitingPayment) return 'Awaiting payment';
    if (isCard && paymentStatus == CustomerPaymentStatus.failed) {
      return 'Payment declined';
    }
    return !isDelivery && status == CustomerOrderStatus.outForDelivery
        ? 'Ready to collect'
        : status.label;
  }

  String get statusExplanation {
    if (wasRejected) {
      return 'The restaurant could not take this order.';
    }
    // The backend holds a card order out of the kitchen until Worldpay's
    // webhook confirms the money, so "we're preparing it" would be false and
    // the customer would stop watching for the thing that still needs doing.
    if (awaitingPayment) {
      return 'Complete payment to confirm your order.';
    }
    if (isCard && paymentStatus == CustomerPaymentStatus.failed) {
      return 'Your card was declined. Your order is saved - try again to '
          'confirm it.';
    }
    return !isDelivery && status == CustomerOrderStatus.ready
        ? 'Your order is ready to collect from the counter.'
        : status.explanation;
  }

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
    wasRejected,
    cancellationReason,
    cancelledAt,
    paymentMethod,
    paymentStatus,
    paymentUrl,
    paidAt,
    itemCountFallback,
  ];
}
