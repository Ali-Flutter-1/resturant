import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/cart/cart_cubit.dart';
import '../../../shared/preview/sample_content.dart';
import '../domain/dish.dart';
import '../domain/spice_level.dart';
import '../../../shared/animations/fly_to_cart.dart';
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

  /// The dish that was tapped, straight from the API.
  ///
  /// It used to arrive as a preview object adapted from the real one, and the
  /// screen filled the gaps with hardcoded copy — so every dish showed the same
  /// description and the same delivery time regardless of what had been tapped.
  final Dish? dish;

  final VoidCallback? onBack;

  /// Fired once the flying copy has landed in the cart.
  final VoidCallback? onAddToCart;

  /// Tapping the cart icon itself.
  final VoidCallback? onOpenCart;

  @override
  State<DishDetailsScreen> createState() => _DishDetailsScreenState();
}

class _DishDetailsScreenState extends State<DishDetailsScreen> {
  SpiceLevel? _spice;
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
        // Spice level is a real API field. Add-ons are not — they go into the
        // line's `notes`, the only free field the API offers on an order line,
        // and are therefore *instructions* rather than priced extras. The server
        // prices from `dish_id` alone, so a paid modifier would be its own dish.
        context.read<CartCubit>().addDish(
          _dish,
          quantity: _quantity,
          notes: _notes(),
          spiceLevel: _spice,
        );
        AppHaptics.success();
        widget.onAddToCart?.call();
      },
    );

    if (mounted) setState(() => _flying = false);
  }

  /// Falls back to an empty dish so the screen still renders standalone, in a
  /// test or before a route has anything to hand it.
  Dish get _dish =>
      widget.dish ??
      const Dish(id: '', name: 'Dish', description: '', pricePence: 0);

  double get _total {
    final addOns = _selectedAddOns.fold<double>(
      0,
      (sum, i) => sum + SampleContent.addOns[i].price,
    );
    return (_dish.price + addOns) * _quantity;
  }

  /// What the kitchen is told about this line.
  ///
  /// The chosen add-ons, in one string of at most 200 characters — the API's
  /// limit. Truncated rather than refused: losing the tail of a long note is
  /// better than refusing to add the dish.
  ///
  /// Spice level is no longer in here. It has its own API field now, and putting
  /// it in free text meant the kitchen ticket carried it but no report could
  /// count it.
  String? _notes() {
    final parts = <String>[
      for (final i in _selectedAddOns) SampleContent.addOns[i].name,
    ];
    final text = parts.join(', ');
    if (text.isEmpty) return null;
    return text.length <= 200 ? text : text.substring(0, 200);
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
                // The hero carries the photograph across from the card, but the
                // body used to arrive all at once beneath it — the flight
                // landed and the page was simply there. Staggering the sections
                // lets the eye follow the same order it reads in.
                children: [
                  // The dish's own sections, not an invented "authenticity"
                  // label — the API carries categories and no such tag.
                  if (_dish.categories.isNotEmpty)
                    _AuthenticityTag(label: _dish.categories.first.name),
                  const SizedBox(height: AppSpacing.x3),
                  Text(_dish.name, style: context.texts.displayLarge),
                  const SizedBox(height: AppSpacing.x2),
                  // The kitchen's own estimate, and only when it sent one. This
                  // was "45-60 min delivery" for every dish on the menu.
                  if (_dish.prepTime != null)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: AppIconSize.sm,
                          color: context.surfaces.inkSoft,
                        ),
                        const SizedBox(width: AppSpacing.x1 + 2),
                        Text(
                          'Ready in ${_dish.prepTime}',
                          style: context.texts.bodyMedium,
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.x5),
                  Text(
                    // The dish's real description. A dish with none says so
                    // rather than borrowing another dish's paragraph.
                    _dish.description.isEmpty
                        ? 'No description yet.'
                        : _dish.description,
                    style: context.texts.bodyLarge?.copyWith(
                      color: scheme.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  const Divider(),
                  const SizedBox(height: AppSpacing.x5),

                  // Only where the kitchen offers it. Sending a level for a dish
                  // with `has_spice_levels` false is a SPICE_LEVEL_NOT_OFFERED,
                  // so the control must not be there to tap.
                  if (_dish.hasSpiceLevels) ...[
                    _ChoiceSection(
                      // Optional, not required: the API accepts no choice, and
                      // forcing one on somebody who does not care is a decision
                      // the backend never asked for.
                      title: 'Spice Level',
                      badge: 'Optional',
                      child: Row(
                        children: [
                          for (final (i, level) in SpiceLevel.values.indexed) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.x3),
                            Expanded(
                              child: _SpiceOption(
                                label: level.label,
                                selected: level == _spice,
                                // Re-tapping clears it, which is the only way
                                // back to "no preference" once one is chosen.
                                onTap: () => setState(
                                  () => _spice = _spice == level ? null : level,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),
                  ],

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
                ].revealStaggered(),
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

  final Dish dish;
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
      // The disc only earns its place if it does something; without a
      // callback the framework's implied BackButton is the honest fallback.
      leading: onBack == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.x2),
              child: Material(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onBack,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, size: AppIconSize.xl),
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
        style: context.texts.labelSmall
            ?.copyWith(color: colours.preparing)
            .withWeight(FontWeight.w600),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.badge,
    required this.child,
  });

  final String title;
  final String badge;
  final Widget child;

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
            // Every section is optional now that spice level is — so the badge
            // is a quiet note rather than the boxed "Required" it used to be.
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
        duration: context.motion.fade(Motion.fast),
        curve: context.motion.standard,
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
        duration: context.motion.fade(Motion.fast),
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
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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
              // Height and radius follow the stepper beside it, so the two read
              // as one control bar rather than two unrelated shapes.
              child: SizedBox(
                height: QuantityStepper.height,
                child: Material(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: onAdd == null
                        ? null
                        : () {
                            AppHaptics.commit();
                            onAdd!();
                          },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'ADD TO CART',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: context.motion.fade(Motion.fast),
                              child: FittedBox(
                                key: ValueKey(total),
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '£${total.toStringAsFixed(2)}',
                                  maxLines: 1,
                                  style: AppTypography.money(
                                    scheme.onPrimary,
                                    size: MoneySize.medium,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Sample reviews so the ratings link is a working control. Replaced by the
/// reviews endpoint when it exists.
