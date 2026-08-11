import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/dish.dart';
import '../domain/menu_repository.dart';

enum CategoriesStatus { loading, ready, failure }

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = CategoriesStatus.loading,
    this.categories = const [],
  });

  final CategoriesStatus status;
  final List<MenuCategory> categories;

  @override
  List<Object?> get props => [status, categories];
}

/// Just the menu's sections.
///
/// Separate from `MenuCubit`, which fetches categories *and* every dish. The
/// home screen's category strip needs only the sections, and making it pull the
/// whole menu to draw five circles would delay the screen it sits on.
///
/// No failure message is carried. A strip that cannot load is hidden rather than
/// replaced by an error: it is one way into the menu among several, and an error
/// panel across the top of the home screen would be louder than the problem.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit({required MenuRepository repository})
    : _repository = repository,
      super(const CategoriesState());

  final MenuRepository _repository;

  Future<void> load() async {
    try {
      emit(
        CategoriesState(
          status: CategoriesStatus.ready,
          categories: await _repository.categories(),
        ),
      );
    } on ApiFailure {
      emit(const CategoriesState(status: CategoriesStatus.failure));
    }
  }
}
