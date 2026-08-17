import 'package:equatable/equatable.dart';

import '../../menu/domain/spice_level.dart';

/// One priced line in a quote.
class QuoteLine extends Equatable {
  const QuoteLine({
    required this.name,
    required this.quantity,
    required this.unitPricePence,
    required this.linePence,
    this.dishId,
    this.spiceLevel,
    this.notes,
  });

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
    name: json['name']?.toString() ?? 'Item',
    dishId: json['dish_id']?.toString(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    unitPricePence: (json['unit_price_pence'] as num?)?.toInt() ?? 0,
    linePence: (json['line_total_pence'] as num?)?.toInt() ?? 0,
    spiceLevel: SpiceLevel.tryParse(json['spice_level']),
    notes: json['notes']?.toString(),
  );

  final String name;

  /// Echoed back by the API, which is what lets the checkout pair a priced line
  /// with the basket line it can edit.
  final String? dishId;

  final int quantity;
  final int unitPricePence;
  final int linePence;
  final SpiceLevel? spiceLevel;
  final String? notes;

  @override
  List<Object?> get props => [
    name,
    dishId,
    quantity,
    unitPricePence,
    linePence,
    spiceLevel,
    notes,
  ];
}

/// The server's price for a basket.
///
/// Nothing here is calculated in the app. The guide is explicit: render the
/// returned prices, not local arithmetic — a total the app worked out is display
/// information, and the server's is the one that gets charged.
class OrderQuote extends Equatable {
  const OrderQuote({
    this.lines = const [],
    this.subtotalPence = 0,
    this.deliveryFeePence = 0,
    this.totalPence = 0,
    this.minimumOrderPence = 0,
    this.meetsMinimum = true,
    this.earliestSlot,
    this.availableSlots = const [],
  });

  factory OrderQuote.fromJson(Map<String, dynamic> json) {
    final lines = json['items'];
    final slots = json['available_slots'];
    return OrderQuote(
      lines: lines is List
          ? lines
                .whereType<Map>()
                .map((l) => QuoteLine.fromJson(Map<String, dynamic>.from(l)))
                .toList()
          : const [],
      subtotalPence: (json['subtotal_pence'] as num?)?.toInt() ?? 0,
      deliveryFeePence: (json['delivery_fee_pence'] as num?)?.toInt() ?? 0,
      totalPence: (json['total_pence'] as num?)?.toInt() ?? 0,
      minimumOrderPence: (json['minimum_order_pence'] as num?)?.toInt() ?? 0,
      meetsMinimum: json['meets_minimum'] != false,
      earliestSlot: _date(json['earliest_slot']),
      // Kept as the API sent them. The guide says to use these rather than
      // rebuilding the slot rules, which is why the raw strings survive
      // alongside the parsed times — `requested_for` must go back exactly as it
      // came, offset included.
      availableSlots: slots is List
          ? slots
                .map((s) => s?.toString())
                .whereType<String>()
                .toList(growable: false)
          : const [],
    );
  }

  static DateTime? _date(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString());

  final List<QuoteLine> lines;
  final int subtotalPence;
  final int deliveryFeePence;
  final int totalPence;
  final int minimumOrderPence;

  /// False blocks placing a delivery order. The delivery fee does not count
  /// towards the minimum, so the shortfall is measured on the subtotal.
  final bool meetsMinimum;

  final DateTime? earliestSlot;

  /// ISO strings, verbatim from the API.
  final List<String> availableSlots;

  /// How much more is needed to reach the minimum, in pence.
  int get shortfallPence {
    final short = minimumOrderPence - subtotalPence;
    return short > 0 ? short : 0;
  }

  static String formatPence(int pence) {
    final pounds = pence ~/ 100;
    final pennies = (pence % 100).toString().padLeft(2, '0');
    return '£$pounds.$pennies';
  }

  String get formattedSubtotal => formatPence(subtotalPence);
  String get formattedFee => formatPence(deliveryFeePence);
  String get formattedTotal => formatPence(totalPence);
  String get formattedShortfall => formatPence(shortfallPence);

  @override
  List<Object?> get props => [
    lines,
    subtotalPence,
    deliveryFeePence,
    totalPence,
    minimumOrderPence,
    meetsMinimum,
    earliestSlot,
    availableSlots,
  ];
}
