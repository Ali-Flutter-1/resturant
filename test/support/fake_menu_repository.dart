import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/features/menu/domain/menu_repository.dart';

/// A menu that answers from memory.
///
/// Shared by every widget test that renders a screen reading the menu, so the
/// fixture stays in one place and a change to the model doesn't have to be
/// chased through four test files.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository({
    List<MenuCategory>? categories,
    List<Dish>? dishes,
    this.failure,
    this.delay = Duration.zero,
  }) : _categories = categories ?? defaultCategories,
       _dishes = dishes ?? defaultDishes;

  /// Thrown by every method when set, for exercising the failure path.
  final ApiFailure? failure;

  /// Lets a test observe the loading state before data lands.
  final Duration delay;

  final List<MenuCategory> _categories;
  final List<Dish> _dishes;

  static const curries = MenuCategory(
    id: 'cat-1',
    slug: 'curry-dishes',
    name: 'Curry Dishes',
    sortOrder: 1,
  );

  static const smallPlates = MenuCategory(
    id: 'cat-2',
    slug: 'small-plates',
    name: 'Small Plates',
    sortOrder: 2,
  );

  static const defaultCategories = [curries, smallPlates];

  static const jaffnaCrab = Dish(
    id: 'd1',
    slug: 'jaffna-crab-curry',
    name: 'Jaffna Crab Curry',
    description: 'Fresh mud crab in roasted spices and coconut milk.',
    pricePence: 2800,
    categoryId: 'cat-1',
  );

  static const jackfruit = Dish(
    id: 'd2',
    slug: 'young-jackfruit-curry',
    name: 'Young Jackfruit Curry',
    description: 'Slow-cooked green jackfruit, entirely plant based.',
    pricePence: 1800,
    categoryId: 'cat-1',
    isVegan: true,
    isVegetarian: true,
  );

  static const hoppers = Dish(
    id: 'd3',
    slug: 'heritage-hoppers',
    name: 'Heritage Hoppers',
    description: 'Fermented rice flour and coconut milk pancakes.',
    pricePence: 950,
    categoryId: 'cat-2',
    isVegetarian: true,
  );

  /// Sold out: the API keeps listing these with `is_available` false so the app
  /// greys them out rather than making the menu appear to shrink.
  static const soldOut = Dish(
    id: 'd4',
    slug: 'black-pork-curry',
    name: 'Black Pork Curry',
    description: 'Dark roasted heritage classic.',
    pricePence: 2200,
    categoryId: 'cat-1',
    isAvailable: false,
  );

  static const defaultDishes = [jaffnaCrab, jackfruit, hoppers, soldOut];

  Future<T> _answer<T>(T value) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failure;
    if (error != null) throw error;
    return value;
  }

  @override
  Future<List<MenuCategory>> categories() => _answer(_categories);

  @override
  Future<List<Dish>> dishes({String? categorySlug}) => _answer(
    categorySlug == null
        ? _dishes
        : _dishes
              .where(
                (d) =>
                    d.categoryId ==
                    _categories
                        .firstWhere(
                          (c) => c.slug == categorySlug,
                          orElse: () => _categories.first,
                        )
                        .id,
              )
              .toList(),
  );

  @override
  Future<Dish> dishBySlug(String slug) =>
      _answer(_dishes.firstWhere((d) => d.slug == slug));
}
