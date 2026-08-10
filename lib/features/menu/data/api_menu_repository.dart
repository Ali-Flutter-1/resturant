import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/dish.dart';
import '../domain/menu_repository.dart';

class ApiMenuRepository implements MenuRepository {
  ApiMenuRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<MenuCategory>> categories() async {
    final rows = await _client.list(ApiConstants.categories);
    return rows.map(MenuCategory.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<Dish>> dishes({String? categorySlug}) async {
    final rows = await _client.list(
      ApiConstants.dishes,
      query: categorySlug == null ? null : {'category': categorySlug},
    );
    return rows.map(Dish.fromJson).toList();
  }

  @override
  Future<Dish> dishBySlug(String slug) async =>
      Dish.fromJson(await _client.object(ApiConstants.dishBySlug(slug)));
}
