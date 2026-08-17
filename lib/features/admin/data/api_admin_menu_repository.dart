import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../menu/domain/dish.dart';
import '../domain/admin_menu_repository.dart';
import '../../../core/network/api_failure.dart';

class ApiAdminMenuRepository implements AdminMenuRepository {
  ApiAdminMenuRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<MenuCategory>> categories() async {
    final rows = await _client.list(ApiConstants.adminCategories);
    return rows.map(MenuCategory.fromJson).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<MenuCategory> createCategory(String name) async {
    final data = await _client.object(
      ApiConstants.adminCategories,
      method: 'POST',
      // Only the name. Slug and sort order are omitted rather than sent empty:
      // the API builds a slug from the name and appends to the menu, and sending
      // nulls would risk overwriting those defaults with nothing.
      body: {'name': name.trim()},
    );
    return MenuCategory.fromJson(data);
  }

  @override
  Future<List<Dish>> dishes({String? categoryId}) async {
    final rows = await _client.list(
      ApiConstants.adminDishes,
      query: categoryId == null ? null : {'category_id': categoryId},
    );
    return rows.map(Dish.fromJson).toList();
  }

  @override
  Future<List<DishPhoto>> uploadImages(List<String> filePaths) async {
    if (filePaths.isEmpty) return const [];
    final rows = await _client.uploadList(
      ApiConstants.adminImageUploads,
      field: 'files',
      filePaths: filePaths,
    );
    return rows.map(DishPhoto.fromJson).toList();
  }

  @override
  Future<Dish> createDish({
    required String title,
    String? description,
    required List<String> categoryIds,
    required int pricePence,
    List<DishPhoto> images = const [],
    int? prepMinMinutes,
    int? prepMaxMinutes,
    bool isAvailable = true,
  }) async {
    final data = await _client.object(
      ApiConstants.adminDishes,
      method: 'POST',
      body: {
        'title': title.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'category_ids': categoryIds,
        'price_pence': pricePence,
        if (images.isNotEmpty) 'images': [for (final i in images) i.toJson()],
        'preparation_time_min_minutes': ?prepMinMinutes,
        'preparation_time_max_minutes': ?prepMaxMinutes,
        'is_available': isAvailable,
      },
    );
    return Dish.fromJson(data);
  }

  @override
  Future<Dish> updateDish(
    String id, {
    String? title,
    String? description,
    List<String>? categoryIds,
    int? pricePence,
    List<DishPhoto>? images,
    int? prepMinMinutes,
    int? prepMaxMinutes,
    bool? isAvailable,
  }) async {
    // Only what was passed. A PATCH that sent every field would turn "make this
    // one sold out" into "overwrite this dish with whatever the screen last
    // read", which is how a stale form quietly reverts somebody else's edit.
    final data = await _client.object(
      ApiConstants.adminDish(id),
      method: 'PATCH',
      body: {
        'title': ?title?.trim(),
        'description': ?description?.trim(),
        'category_ids': ?categoryIds,
        'price_pence': ?pricePence,
        if (images != null) 'images': [for (final i in images) i.toJson()],
        'preparation_time_min_minutes': ?prepMinMinutes,
        'preparation_time_max_minutes': ?prepMaxMinutes,
        'is_available': ?isAvailable,
      },
    );
    return Dish.fromJson(data);
  }

  @override
  Future<void> deleteDish(String id) async =>
      _client.send(ApiConstants.adminDish(id), method: 'DELETE');

  @override
  Future<MenuCategory> setCategoryLogo(
    String categoryId,
    String filePath,
  ) async {
    final data = await _client.upload(
      ApiConstants.adminCategoryLogo(categoryId),
      // The API's field name. Anything else is a 422 that reads as "no file".
      field: 'file',
      filePaths: [filePath],
    );
    if (data is! Map) {
      throw const ApiFailure(
        kind: ApiFailureKind.unknown,
        message: 'The server sent something unexpected. Please try again.',
      );
    }
    return MenuCategory.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<MenuCategory> removeCategoryLogo(String categoryId) async {
    final data = await _client.object(
      ApiConstants.adminCategoryLogo(categoryId),
      method: 'DELETE',
    );
    return MenuCategory.fromJson(data);
  }
}
