import 'package:flutter/material.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/dish_image.dart';
import '../../../shared/widgets/notifications_sheet.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/section_header.dart';

/// The customer home: greeting, search, categories, a featured dish, and
/// what's selling today.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({
    super.key,
    this.onOpenDish,
    this.onOpenMenu,
    this.onSearch,
  });

  final ValueChanged<SampleDish>? onOpenDish;
  final VoidCallback? onOpenMenu;

  /// Opens the full menu, optionally pre-filtered by a query.
  final ValueChanged<String>? onSearch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.x6,
            AppSpacing.gutter,
            AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const _Greeting(),
            const SizedBox(height: AppSpacing.x6),
            _SearchField(onSearch: onSearch),
            const SizedBox(height: AppSpacing.x6),
            const _CategoryStrip(),
            const SizedBox(height: AppSpacing.x6),
            _FeaturedCard(onOrder: onOpenDish),
            const SizedBox(height: AppSpacing.x8),
            SectionHeader(
              title: 'Popular Now',
              actionLabel: 'See All',
              onAction: onOpenMenu,
            ),
            const SizedBox(height: AppSpacing.x3),
            _PopularGrid(onOpenDish: onOpenDish),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good Morning,', style: context.texts.bodyMedium),
              const SizedBox(height: 2),
              Text("T's Lover", style: context.texts.displayLarge),
              const SizedBox(height: AppSpacing.x1),
              Row(
                children: [
                  Icon(
                    Icons.place,
                    size: AppIconSize.sm,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  Text(
                    'Colombo, LK',
                    style: context.texts.bodySmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: AppIconSize.md,
                    color: scheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => showNotificationsSheet(context),
          tooltip: 'Notifications',
          icon: Badge(
            backgroundColor: scheme.primary,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
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
        prefixIcon: Icon(Icons.search, color: context.surfaces.inkSoft),
        suffixIcon: Padding(
          padding: const EdgeInsets.all(AppSpacing.x2),
          child: Material(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: () => onSearch?.call(''),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 34,
                child: Icon(
                  Icons.tune,
                  size: AppIconSize.md,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    ).revealItem(1);
  }
}

class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip();

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SampleContent.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x4),
        itemBuilder: (context, index) {
          final category = SampleContent.categories[index];
          final selected = index == _selected;

          return GestureDetector(
            onTap: () {
              AppHaptics.selection();
              setState(() => _selected = index);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: context.motion.fade(Motion.fast),
                  curve: context.motion.standard,
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? scheme.primary
                        : context.surfaces.accentContainer,
                  ),
                  child: Icon(
                    category.icon,
                    size: AppIconSize.xl,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  category.label,
                  style: context.texts.bodySmall?.copyWith(
                    color: selected ? scheme.primary : context.surfaces.inkSoft,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).revealItem(2);
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({this.onOrder});

  final ValueChanged<SampleDish>? onOrder;

  @override
  Widget build(BuildContext context) {
    final dish = SampleContent.featured;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        children: [
          Positioned.fill(
            child: DishImage(
              name: dish.name,
              imageUrl: dish.imageUrl,
              heroTag: 'dish-${dish.name}',
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE6241C1A), Color(0x40241C1A)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 210,
                  child: Text(
                    dish.name,
                    style: context.texts.displayLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  width: 230,
                  child: Text(
                    dish.description,
                    style: context.texts.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                FilledButton(
                  onPressed: onOrder == null ? null : () => onOrder!(dish),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x5,
                    ),
                    backgroundColor: scheme.primary,
                  ),
                  child: const Text('Order Now'),
                ),
              ],
            ),
          ),
        ],
      ),
    ).revealItem(3);
  }
}

class _PopularGrid extends StatelessWidget {
  const _PopularGrid({this.onOpenDish});

  final ValueChanged<SampleDish>? onOpenDish;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight gives the Row a bounded height to stretch into. Without
    // it, `stretch` inside a ListView asks the cards for infinite height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, dish) in SampleContent.popular.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: _PopularCard(
                dish: dish,
                onTap: onOpenDish,
              ).revealItem(index, after: Motion.staggerFor(4)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.dish, this.onTap});

  final SampleDish dish;
  final ValueChanged<SampleDish>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Pressable(
      onTap: onTap == null ? null : () => onTap!(dish),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: context.surfaces.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
                child: AspectRatio(
                  aspectRatio: 1.25,
                  child: DishImage(
                    name: dish.name,
                    imageUrl: dish.imageUrl,
                    heroTag: 'dish-${dish.name}',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dish.name,
                      style: context.texts.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      dish.description,
                      style: context.texts.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dish.formattedPrice,
                          style: AppTypography.money(scheme.primary, size: 16),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: context.surfaces.accentContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: AppIconSize.md,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
