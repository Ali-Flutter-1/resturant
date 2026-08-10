import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/dish.dart';
import '../domain/menu_repository.dart';

enum MenuStatus { loading, ready, failure }

class MenuState extends Equatable {
  const MenuState({
    this.status = MenuStatus.loading,
    this.categories = const [],
    this.dishes = const [],
    this.failure,
    this.categorySlug,
    this.query = '',
  });

  final MenuStatus status;

  /// Sections as the API orders them, with "All" prepended by the UI rather
  /// than invented here.
  final List<MenuCategory> categories;

  /// Everything live, unfiltered. Filtering is a view concern — see [visible] —
  /// so switching a chip doesn't cost a round trip or a loading flicker.
  final List<Dish> dishes;

  /// Set only when [status] is [MenuStatus.failure]; its message is safe to
  /// show verbatim.
  final ApiFailure? failure;

  /// Null means every section.
  final String? categorySlug;

  final String query;

  /// The dishes a chip and a search box currently leave on screen.
  List<Dish> get visible {
    final needle = query.trim().toLowerCase();
    return dishes.where((dish) {
      final inCategory =
          categorySlug == null ||
          categories
                  .firstWhere(
                    (c) => c.slug == categorySlug,
                    orElse: () =>
                        const MenuCategory(id: '', slug: '', name: ''),
                  )
                  .id ==
              dish.categoryId;

      final matches =
          needle.isEmpty ||
          dish.name.toLowerCase().contains(needle) ||
          dish.description.toLowerCase().contains(needle);

      return inCategory && matches;
    }).toList();
  }

  /// True when the menu loaded but a filter or search excludes everything —
  /// which is a different situation from the menu being empty, and deserves
  /// different words on screen.
  bool get isFilteredEmpty =>
      status == MenuStatus.ready && dishes.isNotEmpty && visible.isEmpty;

  MenuState copyWith({
    MenuStatus? status,
    List<MenuCategory>? categories,
    List<Dish>? dishes,
    ApiFailure? failure,
    String? categorySlug,
    String? query,
    bool clearCategory = false,
    bool clearFailure = false,
  }) {
    return MenuState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      dishes: dishes ?? this.dishes,
      failure: clearFailure ? null : (failure ?? this.failure),
      categorySlug: clearCategory ? null : (categorySlug ?? this.categorySlug),
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    dishes,
    failure,
    categorySlug,
    query,
  ];
}

/// The menu.
///
/// Categories and dishes are fetched together because a dish carries only its
/// `category_id`: without the sections, a category chip has nothing to match
/// against. Fetching them in parallel costs one round trip rather than two.
class MenuCubit extends Cubit<MenuState> {
  MenuCubit({required MenuRepository repository, String? initialQuery})
    : _repository = repository,
      super(MenuState(query: initialQuery ?? ''));

  final MenuRepository _repository;

  /// Loads, or reloads after a failure.
  ///
  /// [silent] keeps whatever is already on screen while refetching, so a
  /// pull-to-refresh doesn't blank a menu the user is reading.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: MenuStatus.loading, clearFailure: true));
    }

    try {
      final results = await Future.wait([
        _repository.categories(),
        _repository.dishes(),
      ]);

      emit(
        state.copyWith(
          status: MenuStatus.ready,
          categories: results[0] as List<MenuCategory>,
          dishes: results[1] as List<Dish>,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      // A silent refresh that fails keeps the stale menu and says so, rather
      // than throwing away content the user can still read.
      emit(
        state.copyWith(
          status: silent && state.dishes.isNotEmpty
              ? MenuStatus.ready
              : MenuStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  /// Null selects every section.
  void selectCategory(String? slug) => emit(
    slug == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categorySlug: slug),
  );

  void search(String query) => emit(state.copyWith(query: query));

  void clearFilters() => emit(state.copyWith(clearCategory: true, query: ''));
}
