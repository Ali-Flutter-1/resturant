import 'dish.dart';

/// Reading the menu. All of it is public — no token, no session.
abstract interface class MenuRepository {
  /// Active, non-archived sections, in menu order.
  Future<List<MenuCategory>> categories();

  /// Live dishes in live categories, in menu order.
  ///
  /// Sold-out dishes are included with [Dish.isAvailable] false; the API is
  /// deliberate about that so the app greys them out rather than making the
  /// menu appear to change through the evening.
  Future<List<Dish>> dishes({String? categorySlug});

  /// One dish in full. Addressed by id — the API dropped its slug route.
  Future<Dish> dishById(String id);
}
