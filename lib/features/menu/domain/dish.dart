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

  /// Sent back verbatim when creating or updating a dish — the API takes exactly
  /// what its upload endpoint returned.
  Map<String, dynamic> toJson() => {'public_id': publicId, 'url': url};

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
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString(),
    imageUrl: json['image_url']?.toString(),
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String slug;
  final String name;
  final String? description;

  /// A photograph for the section, where one has been uploaded. The home
  /// screen's circles use it in place of a glyph.
  final String? imageUrl;

  final int sortOrder;

  @override
  List<Object?> get props => [id, slug, name, description, imageUrl, sortOrder];
}

/// A dish as the public menu describes it.
///
/// Field names follow the API: it calls the dish's name `title`, and a dish
/// belongs to *several* categories rather than one — a dish can appear in more
/// than one section of the menu. Both were different when this was written
/// against an earlier version of the backend, which is why the JSON keys and the
/// Dart names don't line up everywhere; the Dart side keeps `name` because forty
/// call sites read it and "name" is what it is.
class Dish extends Equatable {
  const Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePence,
    this.categories = const [],
    this.images = const [],
    this.imageUrlOverride,
    this.thumbnailUrl,
    this.prepMinMinutes,
    this.prepMaxMinutes,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.allergens = const [],
    this.isAvailable = true,
    this.createdAt,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final categories = json['categories'];
    return Dish(
      id: json['id']?.toString() ?? '',
      // `title` is the API's name for it. `name` is kept as a fallback so a
      // fixture or an older deployment still parses.
      name: (json['title'] ?? json['name'])?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      // Pence, integer, always. Never parsed as a double — money in floating
      // point is how totals end up a penny out.
      pricePence: (json['price_pence'] as num?)?.toInt() ?? 0,
      categories: categories is List
          ? categories
                .whereType<Map>()
                .map((c) => MenuCategory.fromJson(Map<String, dynamic>.from(c)))
                .toList()
          : const [],
      images: images is List
          ? images
                .whereType<Map>()
                .map((i) => DishPhoto.fromJson(Map<String, dynamic>.from(i)))
                .toList()
          : const [],
      // The API computes both, so the app doesn't have to reach into the gallery
      // to find the picture it should draw.
      imageUrlOverride: json['image_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      prepMinMinutes: (json['preparation_time_min_minutes'] as num?)?.toInt(),
      prepMaxMinutes: (json['preparation_time_max_minutes'] as num?)?.toInt(),
      // The current API sends no dietary flags. Still parsed, because the fields
      // are cheap and the badges reappear by themselves if the backend adds them
      // back — see [dietaryTag].
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
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString())?.toLocal(),
    );
  }

  final String id;
  final String name;
  final String description;
  final int pricePence;

  /// Every section this dish appears in. Empty is legitimate — an uncategorised
  /// dish is hidden from the public menu but still exists in admin.
  final List<MenuCategory> categories;

  final List<DishPhoto> images;

  /// The API's own `image_url`, which wins over reaching into [images].
  final String? imageUrlOverride;

  final String? thumbnailUrl;

  /// How long the kitchen says it takes, as a range.
  final int? prepMinMinutes;
  final int? prepMaxMinutes;
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final List<String> allergens;

  /// False means the admin has taken it off the menu. Still listed, not
  /// orderable — the API is explicit about that so the menu doesn't appear to
  /// shrink through the evening.
  final bool isAvailable;

  /// When the dish was added, for showing the newest first.
  final DateTime? createdAt;

  /// The picture to draw. The API's `image_url` first, then the gallery's first
  /// entry, which is the one it treats as primary.
  String? get imageUrl {
    final override = imageUrlOverride;
    if (override != null && override.isNotEmpty) return override;
    return images.isEmpty ? null : images.first.url;
  }

  /// Ids of the sections this dish is in, for filtering without a join.
  List<String> get categoryIds => [for (final c in categories) c.id];

  /// The kitchen's estimate as a phrase, or null where the API sent no times.
  String? get prepTime {
    final min = prepMinMinutes, max = prepMaxMinutes;
    if (min == null && max == null) return null;
    if (min == null || max == null) return '${min ?? max} min';
    return min == max ? '$min min' : '$min–$max min';
  }

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
    name,
    description,
    pricePence,
    categories,
    images,
    imageUrlOverride,
    thumbnailUrl,
    prepMinMinutes,
    prepMaxMinutes,
    isVegetarian,
    isVegan,
    isGlutenFree,
    allergens,
    isAvailable,
    createdAt,
  ];
}
