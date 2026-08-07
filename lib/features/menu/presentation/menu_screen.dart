import 'package:flutter/material.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/dish_image.dart';
import '../../../shared/widgets/notifications_sheet.dart';
import '../../../shared/widgets/pressable.dart';

/// The full menu — a filterable list of large photographic cards.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, this.onOpenDish, this.initialQuery});

  final ValueChanged<SampleDish>? onOpenDish;

  /// Pre-fills the search box when arriving from Discover.
  final String? initialQuery;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _filter = 0;
  late final _search = TextEditingController(text: widget.initialQuery ?? '');
  late String _query = widget.initialQuery ?? '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filtering runs here rather than in the list builder so the empty state
  /// can tell the difference between "no dishes" and "nothing matched".
  List<SampleDish> get _visible {
    final label = SampleContent.menuFilters[_filter].toLowerCase();
    final query = _query.trim().toLowerCase();

    return SampleContent.menu.where((dish) {
      final matchesQuery =
          query.isEmpty ||
          dish.name.toLowerCase().contains(query) ||
          dish.description.toLowerCase().contains(query);

      final matchesFilter = switch (label) {
        'vegan' => dish.tag?.toLowerCase() == 'vegan',
        'curry dishes' => dish.name.toLowerCase().contains('curry'),
        'main dishes' => dish.tag?.toLowerCase() != 'vegan',
        _ => true,
      };

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // This screen is always pushed (from Discover), so it needs a way
        // back. Suppressing the implied leading had removed it: the flag
        // was added to keep a hamburger out, but with no Drawer attached
        // what it actually withheld was the back button, leaving the screen
        // escapable only by the Android system gesture.
        title: const Text("T's Cafe"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () => showNotificationsSheet(context),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.x4,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search the menu...',
                prefixIcon: const Icon(Icons.search, size: AppIconSize.xl),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: AppIconSize.lg),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          _FilterStrip(
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: AppSpacing.x4),
          Expanded(
            child: _visible.isEmpty
                ? _NoMatches(
                    query: _query,
                    onClear: () {
                      _search.clear();
                      setState(() {
                        _query = '';
                        _filter = 0;
                      });
                    },
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      0,
                      AppSpacing.gutter,
                      AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: _visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.x4),
                    itemBuilder: (context, index) {
                      return _MenuCard(
                        dish: _visible[index],
                        onTap: widget.onOpenDish,
                      ).revealItem(index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: SampleContent.menuFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
        itemBuilder: (context, index) {
          final isSelected = index == selected;

          return SelectableChip(
            label: SampleContent.menuFilters[index],
            selected: isSelected,
            onSelected: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.dish, this.onTap});

  final SampleDish dish;
  final ValueChanged<SampleDish>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Pressable(
      // A full-width row: the same 4% as a button would be a much larger
      // absolute movement here.
      scale: Motion.pressScaleLarge,
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.lg),
                    ),
                    child: AspectRatio(
                      aspectRatio: 2.1,
                      child: DishImage(
                        name: dish.name,
                        imageUrl: dish.imageUrl,
                        heroTag: 'dish-${dish.name}',
                      ),
                    ),
                  ),
                  if (dish.tag != null)
                    Positioned(
                      left: AppSpacing.x3,
                      bottom: AppSpacing.x3,
                      child: AppChip(
                        label: dish.tag!,
                        foreground: dish.tag!.toLowerCase() == 'vegan'
                            ? context.orderColors.ready
                            : context.orderColors.preparing,
                        background: dish.tag!.toLowerCase() == 'vegan'
                            ? context.orderColors.readyContainer
                            : context.orderColors.preparingContainer,
                      ),
                    ),
                  Positioned(
                    right: AppSpacing.x3,
                    top: AppSpacing.x3,
                    child: _FavouriteButton(active: dish.isFavourite),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            dish.name,
                            style: context.texts.headlineMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          dish.formattedPrice,
                          style: AppTypography.money(scheme.primary, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(dish.description, style: context.texts.bodyMedium),
                    const SizedBox(height: AppSpacing.x4),
                    OutlinedButton(
                      onPressed: onTap == null ? null : () => onTap!(dish),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.5),
                        ),
                        foregroundColor: scheme.primary,
                      ),
                      child: const Text('Add to Order'),
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

class _FavouriteButton extends StatefulWidget {
  const _FavouriteButton({required this.active});

  final bool active;

  @override
  State<_FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<_FavouriteButton> {
  late bool _active = widget.active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    return GestureDetector(
      onTap: () {
        AppHaptics.toggle();
        setState(() => _active = !_active);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        // Swapping outline for fill is the state change; the scale-in gives
        // it a moment of confirmation. Overshoot is warranted here in a way
        // it never is on a list — this is the user's own deliberate act
        // answering back.
        child: AnimatedSwitcher(
          duration: motion.move(Motion.fast),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: motion.playful),
            child: child,
          ),
          child: Icon(
            _active ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(_active),
            size: AppIconSize.lg,
            color: _active ? scheme.primary : context.surfaces.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Shown when a search or filter excludes everything. The design file has no
/// empty state for any screen, so this is invented — but a filterable list
/// without one leaves the user staring at nothing.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: AppIconSize.hero,
              color: context.surfaces.inkSoft,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              query.isEmpty ? 'Nothing on this filter' : 'No dishes match',
              style: context.texts.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              query.isEmpty
                  ? 'Try another part of the menu.'
                  : 'Nothing matches “$query”. Try a different search.',
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x5),
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ).reveal(),
    );
  }
}
