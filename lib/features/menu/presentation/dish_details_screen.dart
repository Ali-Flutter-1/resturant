import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/cart/cart_cubit.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/animations/fly_to_cart.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/cart_icon_button.dart';
import '../../../shared/widgets/dish_image.dart';
import '../../../shared/widgets/quantity_stepper.dart';

/// One dish in full: photograph, provenance, required spice level, optional
/// add-ons, and a running total that updates as choices are made.
class DishDetailsScreen extends StatefulWidget {
  const DishDetailsScreen({
    super.key,
    this.dish,
    this.onBack,
    this.onAddToCart,
    this.onOpenCart,
  });

  /// The dish that was tapped. Falls back to the featured one so the screen
  /// still renders standalone (tests, deep links before routing exists).
  final SampleDish? dish;

  final VoidCallback? onBack;

  /// Fired once the flying copy has landed in the cart.
  final VoidCallback? onAddToCart;

  /// Tapping the cart icon itself.
  final VoidCallback? onOpenCart;

  @override
  State<DishDetailsScreen> createState() => _DishDetailsScreenState();
}

class _DishDetailsScreenState extends State<DishDetailsScreen> {
  int _spiceLevel = 0;
  final _selectedAddOns = <int>{};
  int _quantity = 1;

  /// Measured at launch to position the flying copy and its destination.
  final _imageKey = GlobalKey();
  final _cartKey = GlobalKey();

  /// Guards against a second flight while one is mid-air, which would leave
  /// two copies racing to the same point.
  bool _flying = false;

  Future<void> _addToCart() async {
    if (_flying) return;
    setState(() => _flying = true);
    AppHaptics.commit();

    await FlyToCart.launch(
      context: context,
      sourceKey: _imageKey,
      targetKey: _cartKey,
      // A copy, not the original — the header image never moves.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: DishImage(name: _dish.name, imageUrl: _dish.imageUrl),
      ),
      onArrive: () {
        if (!mounted) return;
        context.read<CartCubit>().add(_quantity);
        AppHaptics.success();
        widget.onAddToCart?.call();
      },
    );

    if (mounted) setState(() => _flying = false);
  }

  SampleDish get _dish => widget.dish ?? SampleContent.featured;

  double get _total {
    final addOns = _selectedAddOns.fold<double>(
      0,
      (sum, i) => sum + SampleContent.addOns[i].price,
    );
    return (_dish.price + addOns) * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _DishHeader(
            dish: _dish,
            onBack: widget.onBack,
            imageKey: _imageKey,
            cartKey: _cartKey,
            onOpenCart: widget.onOpenCart,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x5,
                AppSpacing.gutter,
                AppSpacing.x8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_dish.tag != null) _AuthenticityTag(label: _dish.tag!),
                  const SizedBox(height: AppSpacing.x3),
                  Text(_dish.name, style: context.texts.displayLarge),
                  const SizedBox(height: AppSpacing.x2),
                  _RatingRow(dish: _dish),
                  const SizedBox(height: AppSpacing.x2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 15,
                        color: context.surfaces.inkSoft,
                      ),
                      const SizedBox(width: AppSpacing.x1 + 2),
                      Text(
                        '45-60 min delivery',
                        style: context.texts.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  Text(
                    'A rich, aromatic fusion of tender pork and authentic Sri '
                    'Lankan spices. Slow-cooked to perfection with roasted '
                    'curry powder, goraka, and black pepper, delivering a '
                    'profound depth of flavor that honors culinary heritage '
                    'while embracing modern refinement.',
                    style: context.texts.bodyLarge?.copyWith(
                      color: scheme.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  const Divider(),
                  const SizedBox(height: AppSpacing.x5),

                  _ChoiceSection(
                    title: 'Spice Level',
                    badge: 'Required',
                    badgeIsRequired: true,
                    child: Row(
                      children: [
                        for (final (i, level)
                            in SampleContent.spiceLevels.indexed) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: _SpiceOption(
                              label: level,
                              selected: i == _spiceLevel,
                              onTap: () => setState(() => _spiceLevel = i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),

                  _ChoiceSection(
                    title: 'Add-ons',
                    badge: 'Optional',
                    child: Column(
                      children: [
                        for (final (i, addOn)
                            in SampleContent.addOns.indexed) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.x3),
                          _AddOnTile(
                            name: addOn.name,
                            description: addOn.description,
                            price: addOn.price,
                            selected: _selectedAddOns.contains(i),
                            onChanged: (on) => setState(() {
                              on
                                  ? _selectedAddOns.add(i)
                                  : _selectedAddOns.remove(i);
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AddToCartBar(
        quantity: _quantity,
        total: _total,
        onQuantityChanged: (q) => setState(() => _quantity = q),
        onAdd: _addToCart,
      ),
    );
  }
}

class _DishHeader extends StatelessWidget {
  const _DishHeader({
    required this.dish,
    required this.imageKey,
    required this.cartKey,
    this.onBack,
    this.onOpenCart,
  });

  final SampleDish dish;
  final GlobalKey imageKey;
  final GlobalKey cartKey;
  final VoidCallback? onBack;
  final VoidCallback? onOpenCart;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      // Overscrolling zooms the photograph, the way a native iOS header does.
      stretch: true,
      stretchTriggerOffset: 120,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2),
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back, size: 20),
            ),
          ),
        ),
      ),
      actions: [
        CartIconButton(targetKey: cartKey, onTap: onOpenCart),
        const SizedBox(width: AppSpacing.x1),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        background: DishImage(
          key: imageKey,
          name: dish.name,
          imageUrl: dish.imageUrl,
          heroTag: 'dish-${dish.name}',
        ),
      ),
    );
  }
}

class _AuthenticityTag extends StatelessWidget {
  const _AuthenticityTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colours.preparingContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: colours.preparing,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.dish});

  final SampleDish dish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (dish.rating == null) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.star, size: 16, color: context.orderColors.preparing),
        const SizedBox(width: AppSpacing.x1),
        Text(dish.rating!.toStringAsFixed(1), style: context.texts.titleMedium),
        const SizedBox(width: AppSpacing.x2),
        InkWell(
          onTap: () => showAppSheet<void>(
            context: context,
            title: 'Reviews',
            subtitle:
                '${dish.rating!.toStringAsFixed(1)} average from '
                '${dish.reviewCount} diners.',
            child: const _Reviews(),
          ),
          child: Text(
            '(${dish.reviewCount} reviews)',
            style: context.texts.bodySmall?.copyWith(
              color: scheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.badge,
    required this.child,
    this.badgeIsRequired = false,
  });

  final String title;
  final String badge;
  final Widget child;
  final bool badgeIsRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(title, style: context.texts.headlineLarge)),
            const SizedBox(width: AppSpacing.x2),
            if (badgeIsRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.surfaces.ground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: context.surfaces.line),
                ),
                child: Text(badge, style: context.texts.labelSmall),
              )
            else
              Text(badge, style: context.texts.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        child,
      ],
    );
  }
}

class _SpiceOption extends StatelessWidget {
  const _SpiceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.standard,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? context.surfaces.accentContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? scheme.primary : context.surfaces.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.texts.titleMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AddOnTile extends StatelessWidget {
  const _AddOnTile({
    required this.name,
    required this.description,
    required this.price,
    required this.selected,
    required this.onChanged,
  });

  final String name;
  final String description;
  final double price;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onChanged(!selected);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : context.surfaces.line,
          ),
          color: selected
              ? context.surfaces.accentContainer.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: scheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.texts.titleMedium),
                  const SizedBox(height: 2),
                  Text(description, style: context.texts.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            Text(
              '+ £${price.toStringAsFixed(2)}',
              style: context.texts.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToCartBar extends StatelessWidget {
  const _AddToCartBar({
    required this.quantity,
    required this.total,
    required this.onQuantityChanged,
    this.onAdd,
  });

  final int quantity;
  final double total;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.x3,
        AppSpacing.gutter,
        AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: context.surfaces.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Proportional rather than a fixed 132pt, so the bar survives a
            // 320pt-wide phone without crushing the price.
            Expanded(
              flex: 4,
              child: QuantityStepper(
                value: quantity,
                onChanged: onQuantityChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              flex: 6,
              child: Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: onAdd == null
                      ? null
                      : () {
                          AppHaptics.commit();
                          onAdd!();
                        },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                      vertical: AppSpacing.x3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'ADD TO CART',
                            maxLines: 2,
                            style: context.texts.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: Motion.quick,
                            child: FittedBox(
                              key: ValueKey(total),
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '£${total.toStringAsFixed(2)}',
                                maxLines: 1,
                                style: AppTypography.money(
                                  scheme.onPrimary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sample reviews so the ratings link is a working control. Replaced by the
/// reviews endpoint when it exists.
class _Reviews extends StatelessWidget {
  const _Reviews();

  static const _items = [
    (
      name: 'Priyanka F.',
      rating: 5,
      body: 'Tastes like my grandmother\'s. The goraka is exactly right.',
    ),
    (
      name: 'James W.',
      rating: 5,
      body: 'Rich and properly hot. Ask for extra roti.',
    ),
    (
      name: 'Aisha R.',
      rating: 4,
      body: 'Excellent depth of flavour, though I would have liked more pork.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.x6),
      itemBuilder: (context, index) {
        final review = _items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(review.name, style: context.texts.titleMedium),
                const SizedBox(width: AppSpacing.x2),
                for (var i = 0; i < review.rating; i++)
                  Icon(
                    Icons.star,
                    size: 13,
                    color: context.orderColors.preparing,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(review.body, style: context.texts.bodyMedium),
          ],
        );
      },
    );
  }
}
