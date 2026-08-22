import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/time/uk_time.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/animations/skeleton.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/network_photo.dart';
import '../../../shared/widgets/dish_image.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/section_header.dart';
import '../../menu/domain/dish.dart';
import '../../menu/domain/menu_repository.dart';
import 'discover_cubit.dart';
import '../../auth/session_refresh.dart';
import '../../../shared/widgets/page_body.dart';

/// The customer home: greeting, search, categories, a featured dish, and
/// what's selling today.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    this.onOpenDish,
    this.onOpenMenu,
    this.onSearch,
    this.onOpenCategory,
  });

  /// Takes an API [Dish]. Sample content used to feed this screen, so the
  /// dishes an admin added were invisible here while being on the real menu.
  final ValueChanged<Dish>? onOpenDish;
  final VoidCallback? onOpenMenu;

  /// Opens the full menu, optionally pre-filtered by a query.
  final ValueChanged<String>? onSearch;

  /// Opens the menu filtered to one section, by slug.
  ///
  /// The strip used to be five hardcoded circles that only changed which one
  /// looked selected — a control that appeared to work and did nothing.
  final ValueChanged<String>? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DiscoverCubit(repository: context.read<MenuRepository>())..load(),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<DiscoverCubit, DiscoverState>(
            builder: (context, state) {
              final cubit = context.read<DiscoverCubit>();

              return RefreshIndicator(
                onRefresh: () =>
                    refreshWithSession(context, () => cubit.load(silent: true)),
                child: ListView(
                  padding: pagePadding(
                    context,
                    top: AppSpacing.x6,
                    bottom:
                        AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    const _Greeting(),
                    const SizedBox(height: AppSpacing.x6),
                    _SearchField(onSearch: onSearch),
                    const SizedBox(height: AppSpacing.x6),
                    _CategoryStrip(
                      categories: state.categories,
                      loading: state.status == DiscoverStatus.loading,
                      onSelected: onOpenCategory,
                    ),
                    const SizedBox(height: AppSpacing.x6),
                    _MenuHighlights(
                      state: state,
                      onOpenDish: onOpenDish,
                      onOpenMenu: onOpenMenu,
                      onRetry: () => cubit.load(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The featured dish, then a horizontal strip of what else is on the menu.
///
/// One widget because the three states — loading, failed, loaded — apply to both
/// halves at once: they come from the same request.
class _MenuHighlights extends StatelessWidget {
  const _MenuHighlights({
    required this.state,
    required this.onRetry,
    this.onOpenDish,
    this.onOpenMenu,
  });

  final DiscoverState state;
  final Future<void> Function() onRetry;
  final ValueChanged<Dish>? onOpenDish;
  final VoidCallback? onOpenMenu;

  @override
  Widget build(BuildContext context) {
    if (state.status == DiscoverStatus.loading) {
      return const _HighlightsSkeleton();
    }
    if (state.status == DiscoverStatus.failure && state.failure != null) {
      // Inline rather than replacing the screen: the greeting, search and
      // categories above are still usable, and a full-page error would take
      // them away too.
      return ApiErrorView(failure: state.failure!, onRetry: onRetry);
    }

    final heroes = state.heroes;
    final strip = state.strip;
    if (heroes.isEmpty) {
      return const _NoDishesYet();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Side by side and swipeable rather than stacked: two full-width cards
        // one above the other pushed everything else off the screen, and the
        // second was only ever seen by someone who scrolled.
        _HeroCarousel(dishes: heroes, onOpenDish: onOpenDish),
        if (strip.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x8),
          SectionHeader(
            title: 'On the menu',
            actionLabel: 'See All',
            onAction: onOpenMenu,
          ),
          const SizedBox(height: AppSpacing.x3),
          _DishStrip(dishes: strip, onOpenDish: onOpenDish),
        ],
      ],
    );
  }
}

/// The latest dishes, one screen-width at a time.
///
/// A [PageView] rather than a scrolling list: these are full-width cards, and a
/// pager snaps so a card is never left half on screen. `viewportFraction` leaves
/// a sliver of the next one showing, which is what says "swipe" without a label.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.dishes, this.onOpenDish});

  final List<Dish> dishes;
  final ValueChanged<Dish>? onOpenDish;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  // Full width, so a card's left and right edges land on the page gutter —
  // the same line the search bar sits on. A fractional viewport left the
  // cards inset by a different amount from everything above them, which is
  // what made the screen look untidy.
  late final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 16:10, so the pager has a bounded height without cropping the cards.
        AspectRatio(
          aspectRatio: 16 / 10,
          // The pager runs the full width of the screen while each *page* keeps
          // the page gutter. Two things fall out of that, and they were
          // previously in conflict: a card's edges land exactly on the gutter —
          // the line the search bar sits on — and consecutive cards are a full
          // gutter apart, so mid-swipe they never touch.
          //
          // `OverflowBox` is what lets the pager exceed the width its parent
          // allows. Escaping the page's own padding any other way would mean
          // restructuring every child of the screen to pad itself.
          child: OverflowBox(
            maxWidth: MediaQuery.sizeOf(context).width,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.dishes.length,
              onPageChanged: (page) {
                AppHaptics.selection();
                setState(() => _page = page);
              },
              itemBuilder: (context, index) => Padding(
                // The same inset the page itself uses, so a card's edges keep
                // landing on the line the search bar sits on at every width.
                padding: EdgeInsets.symmetric(
                  horizontal: pageSideInset(context),
                ),
                child: _FeaturedCard(
                  dish: widget.dishes[index],
                  onOrder: widget.onOpenDish,
                  position: index,
                ),
              ),
            ),
          ),
        ),
        if (widget.dishes.length > 1) ...[
          const SizedBox(height: AppSpacing.x3),
          _PageDots(count: widget.dishes.length, current: _page),
        ],
      ],
    );
  }
}

/// Which card you are on.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x1 + 2),
          AnimatedContainer(
            duration: motion.move(Motion.fast),
            curve: motion.standard,
            // The current dot stretches rather than growing: a row of circles
            // where one is bigger reads as a mistake at this size.
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? scheme.primary : context.surfaces.line,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ],
    );
  }
}

/// Up to six dishes, side by side.
///
/// A horizontal strip rather than the two-card row this used to be: a row of two
/// reads as "here are two dishes", and the menu is longer than that. Fixed-width
/// cards so the last one is clipped at the edge, which is what tells you there
/// is more to swipe.
class _DishStrip extends StatelessWidget {
  const _DishStrip({required this.dishes, this.onOpenDish});

  final List<Dish> dishes;
  final ValueChanged<Dish>? onOpenDish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // The square photograph plus the two caption lines under it. The card no
      // longer carries a description, so it is a good deal shorter than the 268
      // the old panel needed.
      height: _PopularCard.imageSize + 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Bleeds to the screen edges, so a card can sit half-off it. The list's
        // own padding replaces the page gutter the parent would otherwise apply.
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: dishes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x3),
        itemBuilder: (context, index) => SizedBox(
          // Square photograph, so the card is as wide as the image is tall.
          width: _PopularCard.imageSize,
          child: _PopularCard(
            dish: dishes[index],
            onTap: onOpenDish,
          ).revealItem(index, after: Motion.staggerFor(4)),
        ),
      ),
    );
  }
}

/// Placeholders at the real size, so the screen does not jump on arrival.
class _HighlightsSkeleton extends StatelessWidget {
  const _HighlightsSkeleton();

  @override
  Widget build(BuildContext context) {
    final ground = context.surfaces.accentContainer;

    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ground,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < DiscoverState.heroCount; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.x1 + 2),
                Container(
                  width: i == 0 ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: ground,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.x8),
          Container(
            width: 140,
            height: 20,
            decoration: BoxDecoration(
              color: ground,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          SizedBox(
            height: 268,
            // A horizontal list, not a Row: three 168pt cards are wider than the
            // screen, which is the point — the strip they stand in for scrolls.
            // A Row would overflow rather than run off the edge.
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x3),
              itemBuilder: (context, _) => Container(
                width: 168,
                decoration: BoxDecoration(
                  color: ground,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The menu is empty — which for an admin means "add the first dish", and for a
/// customer means the kitchen has not published one yet.
class _NoDishesYet extends StatelessWidget {
  const _NoDishesYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Column(
        children: [
          Icon(
            // Deliberately not `restaurant_menu`, which a category circle falls
            // back to — two different meanings should not share a glyph.
            Icons.hourglass_empty,
            size: AppIconSize.hero,
            color: context.surfaces.inkSoft,
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'The menu is being prepared',
            style: context.texts.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Check back shortly — dishes appear here as soon as the kitchen '
            'publishes them.',
            style: context.texts.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // On the restaurant's clock, not the device's — and no longer the
              // literal words "Good Morning," at every hour of the day.
              Text('${UkTime.greeting()},', style: context.texts.bodyMedium),
              const SizedBox(height: 2),
              Text("T's Lover", style: context.texts.displayLarge),
              // The "Colombo, LK" line is gone. It named the wrong country, and
              // its pin and chevron looked like a location picker that opened
              // nothing.
            ],
          ),
        ),
        // The real unread count, rather than a dot that was always there.
        NotificationBell(onOpen: () => openNotifications(context)),
      ],
    ).reveal();
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({this.onSearch});

  /// Search runs on the full menu, so submitting hands off to that screen.
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) onSearch?.call(value.trim());
      },
      decoration: InputDecoration(
        hintText: 'Search for curries, rolls...',
        fillColor: context.surfaces.ground == AppColors.neutral25
            ? AppColors.neutral50
            : scheme.surface,
        // No filter button. It opened the full menu with no filter applied,
        // which is what the search box does anyway — a control that looks like
        // it narrows something and doesn't.
        prefixIcon: Icon(Icons.search, color: context.surfaces.inkSoft),
      ),
    ).revealItem(1);
  }
}

/// The menu's sections, from `/categories`.
///
/// Replaces five hardcoded circles — Breakfast, Curry, Kottu, Sides, Drinks —
/// which were invented for the design and had no relationship to what the
/// kitchen actually serves. Whatever an admin creates now appears here.
///
/// Tapping one opens the menu filtered to it. Before, tapping only moved a
/// highlight: a control that looked like it worked and did nothing.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.loading,
    this.onSelected,
  });

  final List<MenuCategory> categories;
  final bool loading;

  /// Called with the category's slug, which is what the menu filters on.
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    // Hidden rather than replaced by an error. It is one way into the menu among
    // several, and an error panel across the top of the home screen would be
    // louder than the problem.
    if (!loading && categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 84,
      child: loading
          // Placeholders at the real size, so the screen does not jump when the
          // sections land.
          ? const _CategoryStripSkeleton()
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x4),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryCircle(
                  category: category,
                  onTap: onSelected == null
                      ? null
                      : () {
                          AppHaptics.selection();
                          onSelected!(category.slug);
                        },
                );
              },
            ),
    ).revealItem(2);
  }
}

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({required this.category, this.onTap});

  final MenuCategory category;
  final VoidCallback? onTap;

  /// A glyph chosen from the section's name.
  ///
  /// The API carries an `image_url` but no icon, and a section with no picture
  /// still needs *something* in the circle. Matching on the name is a guess, so
  /// it falls back to a plate rather than to nothing — and a wrong-but-plausible
  /// glyph beside a correct label reads better than an empty ring.
  IconData get _icon {
    final name = category.name.toLowerCase();
    if (name.contains('breakfast')) return Icons.egg_alt_outlined;
    if (name.contains('drink') || name.contains('beverage')) {
      return Icons.local_cafe_outlined;
    }
    if (name.contains('side')) return Icons.lunch_dining_outlined;
    if (name.contains('curry')) return Icons.ramen_dining_outlined;
    if (name.contains('kottu') || name.contains('rice')) {
      return Icons.rice_bowl_outlined;
    }
    if (name.contains('dessert') || name.contains('sweet')) {
      return Icons.icecream_outlined;
    }
    if (name.contains('starter') || name.contains('small')) {
      return Icons.tapas_outlined;
    }
    return Icons.restaurant_menu;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = category.imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaces.accentContainer,
              ),
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(_icon, size: AppIconSize.xl, color: scheme.primary)
                  : NetworkPhoto(
                      url: imageUrl,
                      // A broken image falls back to the glyph rather than to
                      // Flutter's grey error box.
                      errorBuilder: (context, _, _) => Icon(
                        _icon,
                        size: AppIconSize.xl,
                        color: scheme.primary,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circles at the real size while the sections load.
class _CategoryStripSkeleton extends StatelessWidget {
  const _CategoryStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x4),
        itemBuilder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.surfaces.accentContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            Container(
              width: 44,
              height: 10,
              decoration: BoxDecoration(
                color: context.surfaces.accentContainer,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.dish,
    required this.position,
    this.onOrder,
  });

  final Dish dish;

  /// Where it sits in the pair, for staggering the entrance.
  final int position;

  final ValueChanged<Dish>? onOrder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Pressable(
      onTap: onOrder == null || !dish.isAvailable ? null : () => onOrder!(dish),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AspectRatio(
          // The photograph is the card. A fixed height would letterbox a
          // portrait image or crop a landscape one to a slot; a ratio lets the
          // image fill the full width at a shape that suits food.
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DishImage(
                name: dish.name,
                imageUrl: dish.imageUrl,
                heroTag: 'dish-${dish.id}',
              ),
              // Bottom-up scrim rather than the old left-to-right one: the text
              // now sits along the bottom edge, so that is where the contrast
              // has to be. Transparent at the top, so the photograph is not
              // dulled across the part of it you are meant to look at.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.55, 1.0],
                    colors: [
                      Color(0xF2241C1A),
                      Color(0x66241C1A),
                      Color(0x00241C1A),
                    ],
                  ),
                ),
              ),
              // "New" only on the first, and only when the API told us when it
              // was added — a badge on a dish whose age is unknown is a guess.
              if (position == 0 && dish.createdAt != null)
                Positioned(
                  top: AppSpacing.x4,
                  left: AppSpacing.x4,
                  child: AppChip.status(
                    label: 'New',
                    foreground: scheme.onPrimary,
                    background: scheme.primary,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dish.name,
                        style: context.texts.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dish.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Text(
                          dish.description,
                          style: context.texts.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.x3),
                      Row(
                        children: [
                          Text(
                            dish.formattedPrice,
                            style: AppTypography.money(
                              Colors.white,
                              size: MoneySize.small,
                            ),
                          ),
                          if (dish.prepTime != null) ...[
                            const SizedBox(width: AppSpacing.x3),
                            Icon(
                              Icons.schedule,
                              size: AppIconSize.sm,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: AppSpacing.x1),
                            Flexible(
                              child: Text(
                                dish.prepTime!,
                                style: context.texts.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const Spacer(),
                          FilledButton(
                            onPressed: onOrder == null || !dish.isAvailable
                                ? null
                                : () => onOrder!(dish),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x4,
                              ),
                              backgroundColor: scheme.primary,
                            ),
                            child: Text(
                              dish.isAvailable ? 'Order' : 'Not available',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).revealItem(3 + position);
  }
}

/// A dish in the horizontal strip.
///
/// The delivery-app card: a big rounded photograph with a round add button
/// sitting on its corner, then the name and the price underneath. No surface, no
/// shadow, no description — the picture is the card, and everything else is a
/// caption. The old version was a shadowed panel with two lines of description,
/// which made four dishes look like four documents.
class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.dish, this.onTap});

  final Dish dish;
  final ValueChanged<Dish>? onTap;

  /// Square, like the strip's width. The photograph is the whole card, so it
  /// gets a stated size rather than an aspect ratio — a ratio makes the block's
  /// height depend on the width it happens to be given, which is what used to
  /// make a card with a photo and one without disagree.
  static const double imageSize = 152;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && dish.isAvailable;

    return Pressable(
      onTap: enabled ? () => onTap!(dish) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // `clipBehavior: none` so the add button can sit over the photo's
          // edge without being cut in half.
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: imageSize,
                  width: double.infinity,
                  child: DishImage(
                    name: dish.name,
                    imageUrl: dish.imageUrl,
                    heroTag: 'dish-${dish.id}',
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.x2,
                bottom: AppSpacing.x2,
                child: _AddBadge(available: dish.isAvailable),
              ),
              // Said, not implied. A greyed-out button on a photograph reads as
              // a loading state; the word is what makes it a sold-out dish.
              if (!dish.isAvailable)
                Positioned(
                  left: AppSpacing.x2,
                  top: AppSpacing.x2,
                  child: AppChip.status(
                    label: 'Not available',
                    foreground: context.orderColors.overdue,
                    background: Theme.of(context).colorScheme.surface,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2 + 2),
          Text(
            dish.name,
            style: context.texts.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            dish.formattedPrice,
            style: AppTypography.money(
              context.surfaces.inkMuted,
              size: MoneySize.small,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The round add button on the photograph's corner.
///
/// Not separately tappable: the whole card opens the dish, which is where the
/// quantity and any extras are chosen. A second target that did something
/// slightly different in the same 30 points would be a trap.
class _AddBadge extends StatelessWidget {
  const _AddBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        boxShadow: context.surfaces.cardShadow,
      ),
      child: Icon(
        // A sold-out dish is not addable, and the glyph says which it is rather
        // than the tap silently doing nothing.
        available ? Icons.add_rounded : Icons.block,
        size: AppIconSize.xl,
        color: available ? scheme.primary : context.surfaces.inkSoft,
      ),
    );
  }
}
