import 'package:equatable/equatable.dart';

/// One picture in a dish's gallery.
///
/// Named `DishPhoto` rather than `DishImage` because the widget that draws one
/// already owns that name; two `DishImage`s in scope is a needless ambiguity.
///
/// The API returns a Cloudinary `public_id` alongside the URL. The id is what
/// admin reorder and remove operations address, so it is kept even though only
/// the URL is needed to draw anything.
class DishPhoto extends Equatable {
  const DishPhoto({required this.publicId, required this.url});

  factory DishPhoto.fromJson(Map<String, dynamic> json) => DishPhoto(
    publicId: json['public_id']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );

  final String publicId;
  final String url;

  @override
  List<Object?> get props => [publicId, url];
}

/// A section of the menu.
class MenuCategory extends Equatable {
  const MenuCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.sortOrder = 0,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString(),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String slug;
  final String name;
  final String? description;
  final int sortOrder;

  @override
  List<Object?> get props => [id, slug, name, description, sortOrder];
}

/// A dish as the public menu describes it.
class Dish extends Equatable {
  const Dish({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.pricePence,
    required this.categoryId,
    this.images = const [],
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.allergens = const [],
    this.isAvailable = true,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    return Dish(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      // Pence, integer, always. Never parsed as a double — money in floating
      // point is how totals end up a penny out.
      pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
      categoryId: json['category_id']?.toString() ?? '',
      images: images is List
          ? images
                .whereType<Map>()
                .map((i) => DishPhoto.fromJson(Map<String, dynamic>.from(i)))
                .toList()
          : const [],
      isVegetarian: json['is_vegetarian'] == true,
      isVegan: json['is_vegan'] == true,
      isGlutenFree: json['is_gluten_free'] == true,
      allergens:
          (json['allergens'] as List?)?.whereType<String>().toList() ??
          const [],
      // Absent means available. A sold-out dish is still listed — the API is
      // explicit that it comes back with this false so the app can grey it out
      // rather than hide it.
      isAvailable: json['is_available'] != false,
    );
  }

  final String id;
  final String slug;
  final String name;
  final String description;
  final int pricePence;
  final String categoryId;
  final List<DishPhoto> images;
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final List<String> allergens;

  /// False means sold out today. Still on the menu, not orderable.
  final bool isAvailable;

  /// The thumbnail: the API treats the first image as the primary one.
  String? get imageUrl => images.isEmpty ? null : images.first.url;

  double get price => pricePence / 100;

  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  /// The single badge worth showing on a card. Vegan is the stronger claim, so
  /// it wins over vegetarian; a dish with neither shows nothing rather than an
  /// invented label.
  String? get dietaryTag {
    if (isVegan) return 'Vegan';
    if (isVegetarian) return 'Vegetarian';
    if (isGlutenFree) return 'Gluten free';
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    description,
    pricePence,
    categoryId,
    images,
    isVegetarian,
    isVegan,
    isGlutenFree,
    allergens,
    isAvailable,
  ];
}
