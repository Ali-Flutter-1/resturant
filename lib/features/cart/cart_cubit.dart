import 'package:flutter_bloc/flutter_bloc.dart';

/// How many items are in the basket.
///
/// Deliberately minimal — the basket's real shape (line items, modifiers,
/// pricing) arrives with the API contract. All the fly-to-cart animation
/// needs is a count to bump, and a signal the badge can react to.
class CartCubit extends Cubit<int> {
  CartCubit() : super(0);

  void add([int quantity = 1]) => emit(state + quantity);

  void clear() => emit(0);
}
