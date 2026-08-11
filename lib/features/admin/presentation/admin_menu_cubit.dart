import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../menu/domain/dish.dart';
import '../domain/admin_menu_repository.dart';

enum AdminMenuStatus { loading, ready, failure }

class AdminMenuState extends Equatable {
  const AdminMenuState({
    this.status = AdminMenuStatus.loading,
    this.categories = const [],
    this.dishes = const [],
    this.failure,
    this.categoryId,
    this.query = '',
    this.busyIds = const {},
  });

  final AdminMenuStatus status;

  /// Every category, hidden ones included — this is the admin list.
  final List<MenuCategory> categories;

  /// Every dish, unfiltered. Filtering is a view concern (see [visible]) so
  /// switching a chip costs no round trip and no loading flicker.
  final List<Dish> dishes;

  final ApiFailure? failure;

  /// Null means every section.
  final String? categoryId;

  final String query;

  /// Dishes with a request in flight, so only those rows show a spinner and
  /// only those controls are disabled. A screen-wide flag would freeze the whole
  /// list because one switch was toggled.
  final Set<String> busyIds;

  List<Dish> get visible {
    final needle = query.trim().toLowerCase();
    return dishes.where((dish) {
      final inCategory =
          categoryId == null || dish.categoryIds.contains(categoryId);
      final matches =
          needle.isEmpty ||
          dish.name.toLowerCase().contains(needle) ||
          dish.description.toLowerCase().contains(needle);
      return inCategory && matches;
    }).toList();
  }

  int get availableCount => dishes.where((d) => d.isAvailable).length;

  /// True when the menu loaded but a filter excludes everything — a different
  /// situation from an empty menu, and it deserves different words.
  bool get isFilteredEmpty =>
      status == AdminMenuStatus.ready && dishes.isNotEmpty && visible.isEmpty;

  AdminMenuState copyWith({
    AdminMenuStatus? status,
    List<MenuCategory>? categories,
    List<Dish>? dishes,
    ApiFailure? failure,
    String? categoryId,
    String? query,
    Set<String>? busyIds,
    bool clearCategory = false,
    bool clearFailure = false,
  }) {
    return AdminMenuState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      dishes: dishes ?? this.dishes,
      failure: clearFailure ? null : (failure ?? this.failure),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      query: query ?? this.query,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    dishes,
    failure,
    categoryId,
    query,
    busyIds,
  ];
}

/// The menu, as staff manage it.
///
/// Every mutation here is write-then-adopt rather than optimistic: the screen
/// shows what the server confirmed. For a menu that is the right trade — an
/// availability switch that flips locally and silently fails leaves the kitchen
/// believing a sold-out dish is off the menu while customers keep ordering it.
class AdminMenuCubit extends Cubit<AdminMenuState> {
  AdminMenuCubit({required AdminMenuRepository repository})
    : _repository = repository,
      super(const AdminMenuState());

  final AdminMenuRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: AdminMenuStatus.loading, clearFailure: true));
    }

    try {
      // In parallel: a dish carries its categories, but the chip strip needs the
      // full list including sections that are currently empty.
      final results = await Future.wait([
        _repository.categories(),
        _repository.dishes(),
      ]);

      emit(
        state.copyWith(
          status: AdminMenuStatus.ready,
          categories: results[0] as List<MenuCategory>,
          dishes: results[1] as List<Dish>,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.dishes.isNotEmpty
              ? AdminMenuStatus.ready
              : AdminMenuStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  void selectCategory(String? id) => emit(
    id == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: id),
  );

  void search(String query) => emit(state.copyWith(query: query));

  /// Puts a created or edited dish into the list without a reload.
  void adopt(Dish dish) {
    final existing = state.dishes.any((d) => d.id == dish.id);
    emit(
      state.copyWith(
        dishes: existing
            ? [
                for (final d in state.dishes)
                  if (d.id == dish.id) dish else d,
              ]
            : [...state.dishes, dish],
      ),
    );
  }

  /// Adds a category created inside the editor, so its chip appears at once.
  void adoptCategory(MenuCategory category) {
    if (state.categories.any((c) => c.id == category.id)) return;
    emit(state.copyWith(categories: [...state.categories, category]));
  }

  /// Turns a dish on or off for tonight.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> setAvailability(String id, bool isAvailable) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      final updated = await _repository.updateDish(
        id,
        isAvailable: isAvailable,
      );
      adopt(updated);
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      return null;
    } on ApiFailure catch (failure) {
      // The switch snaps back, because the state it was showing was never true.
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      return failure.message;
    }
  }

  /// Removes a dish for good.
  ///
  /// Returns an error message to show, or null on success. There is no undo: the
  /// API has no restore route for dishes, so offering one would be a lie. Past
  /// orders keep their own copy of the title and price, so history is unaffected.
  Future<String?> deleteDish(String id) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      await _repository.deleteDish(id);
      emit(
        state.copyWith(
          dishes: [
            for (final d in state.dishes)
              if (d.id != id) d,
          ],
          busyIds: {...state.busyIds}..remove(id),
        ),
      );
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      return failure.message;
    }
  }
}
