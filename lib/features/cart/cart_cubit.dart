import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../menu/domain/dish.dart';

/// One line in the basket.
///
/// Only [dishId], [quantity] and [notes] are sent to the API. The title and
/// price are cached for display and are **not** authoritative — the server looks
/// prices up from `dish_id`, and the integration guide is explicit that anything
/// a client could set, a client could forge. So a price shown here is
/// information, never a claim.
class CartLine extends Equatable {
  const CartLine({
    required this.dishId,
    required this.title,
    required this.displayPricePence,
    required this.quantity,
    this.notes,
    this.prepMaxMinutes,
  });

  factory CartLine.fromDish(Dish dish, {int quantity = 1, String? notes}) =>
      CartLine(
        dishId: dish.id,
        title: dish.name,
        displayPricePence: dish.pricePence,
        quantity: quantity,
        notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
        // Carried so the checkout can refuse a slot the kitchen cannot make.
        prepMaxMinutes: dish.prepMaxMinutes,
      );

  final String dishId;
  final String title;
  final int displayPricePence;
  final int quantity;

  /// Up to 200 characters, per the API. What the kitchen reads on the ticket.
  final String? notes;

  /// The longest the kitchen says this dish takes, in minutes. Null when the API
  /// sent no estimate for it.
  final int? prepMaxMinutes;

  /// Display only. The server recalculates every total when the order is placed.
  int get displayLinePence => displayPricePence * quantity;

  /// Exactly the three fields the API accepts on a line.
  Map<String, dynamic> toJson() => {
    'dish_id': dishId,
    'quantity': quantity,
    'notes': ?notes,
  };

  CartLine copyWith({int? quantity, String? notes}) => CartLine(
    dishId: dishId,
    title: title,
    displayPricePence: displayPricePence,
    quantity: quantity ?? this.quantity,
    notes: notes ?? this.notes,
    prepMaxMinutes: prepMaxMinutes,
  );

  @override
  List<Object?> get props => [
    dishId,
    title,
    displayPricePence,
    quantity,
    notes,
  ];
}

class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  /// What the badge shows: items, not lines. Three of one dish is three items.
  int get count => lines.fold(0, (sum, line) => sum + line.quantity);

  bool get isEmpty => lines.isEmpty;

  /// Display only — the checkout renders the server's quote, not this.
  int get displaySubtotalPence =>
      lines.fold(0, (sum, line) => sum + line.displayLinePence);

  /// How long the whole basket takes the kitchen, in minutes.
  ///
  /// The **longest** dish, not the sum of them. A kitchen cooks in parallel: a
  /// twenty-minute curry alongside a five-minute side is ready in twenty, not
  /// twenty-five. Adding them up would push every multi-item order absurdly far
  /// into the evening.
  ///
  /// Null when no dish in the basket carries an estimate, in which case the
  /// checkout falls back to the server's own lead time and nothing is narrowed.
  int? get longestPrepMinutes {
    final known = lines
        .map((line) => line.prepMaxMinutes)
        .whereType<int>()
        .toList();
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a > b ? a : b);
  }

  /// The API's limits: 1–50 lines, 1–50 per line.
  static const int maxLines = 50;
  static const int maxQuantity = 50;

  @override
  List<Object?> get props => [lines];
}

/// The basket, which lives entirely in the app.
///
/// It was a bare `Cubit<int>` — a counter for the badge — which meant there was
/// nothing to place an order *with*. It now holds real lines, and
/// [CartState.count] preserves what the badge was reading.
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  /// Adds a dish, merging into an existing line when it is the same dish with
  /// the same note.
  ///
  /// Merging matters: two taps of "add" should read as one line of two, not two
  /// lines of one. A *different* note makes it a genuinely different instruction
  /// to the kitchen, so that stays separate.
  void addDish(Dish dish, {int quantity = 1, String? notes}) {
    final tidied = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
    final existing = state.lines.indexWhere(
      (line) => line.dishId == dish.id && line.notes == tidied,
    );

    if (existing >= 0) {
      final line = state.lines[existing];
      // Capped rather than refused: the API rejects more than fifty of one
      // line, and silently clamping is kinder than an error for a long press.
      final merged = line.copyWith(
        quantity: (line.quantity + quantity).clamp(1, CartState.maxQuantity),
      );
      emit(
        CartState(
          lines: [
            for (final (index, l) in state.lines.indexed)
              if (index == existing) merged else l,
          ],
        ),
      );
      return;
    }

    if (state.lines.length >= CartState.maxLines) return;
    emit(
      CartState(
        lines: [
          ...state.lines,
          CartLine.fromDish(
            dish,
            quantity: quantity.clamp(1, CartState.maxQuantity),
            notes: tidied,
          ),
        ],
      ),
    );
  }

  /// Sets a line's quantity. Zero removes it — which is what a customer means by
  /// tapping "minus" on a single item.
  void setQuantity(CartLine line, int quantity) {
    if (quantity <= 0) return remove(line);
    emit(
      CartState(
        lines: [
          for (final l in state.lines)
            if (l == line)
              l.copyWith(quantity: quantity.clamp(1, CartState.maxQuantity))
            else
              l,
        ],
      ),
    );
  }

  void remove(CartLine line) => emit(
    CartState(
      lines: [
        for (final l in state.lines)
          if (l != line) l,
      ],
    ),
  );

  /// Emptied only once the server has confirmed an order — see the checkout.
  void clear() => emit(const CartState());
}
