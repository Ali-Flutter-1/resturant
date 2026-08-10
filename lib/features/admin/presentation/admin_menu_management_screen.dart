import 'package:flutter/material.dart';

import '../../../core/animations/collapse.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/dish_image.dart';
import 'dish_editor_sheet.dart';

/// What's on and what's off tonight.
///
/// Transcribed from "Admin Mobile: Menu Management (Polished)" (`1:3368`) —
/// but from the frame's *metadata* only, because the Figma MCP quota allows no
/// more than a call or two on this plan. Layout, geometry and copy are the
/// design's; every colour, weight and radius is this app's existing token,
/// inferred rather than read off the frame. Treat the styling as unverified.
///
/// Geometry taken from the frame: 44pt search row, 38pt category pills, 114pt
/// list items on a 32pt rhythm, 80pt thumbnail, 46pt floating action button.
class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
  /// Every piece of per-dish state is keyed by the dish's *original* name
  /// rather than its position.
  ///
  /// Position was fine while dishes could only be appended, but deleting one
  /// shifts every index after it — which would silently move "unavailable"
  /// onto a different dish. The original name also survives a rename, so an
  /// edit cannot detach a dish from its own state.
  ///
  /// Seeded by name rather than by `SampleContent.menu[3]`: an index into a
  /// list this screen doesn't own throws the moment that list gets shorter,
  /// whereas a name that no longer exists simply seeds nothing. `late` is
  /// unnecessary here — the initialiser touches only statics, never `this`.
  final _unavailable = <String>{'Tempered Dhal'};

  /// Dishes added during this session, kept beside the const preview list.
  final _added = <SampleDish>[];

  /// Dishes removed this session. The preview list is const, so removal is
  /// recorded here rather than by mutating it — which is also what makes undo
  /// a one-line operation.
  final _deleted = <String>{};

  /// Edits made this session, against the dish's original name.
  final _edits = <String, SampleDish>{};

  /// The row currently folding shut. It is still in [_dishes] while it
  /// animates — dropping it from state first is exactly the jump the fold
  /// exists to avoid.
  String? _collapsing;

  int _category = 0;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The menu as it now stands: preview content plus additions, with deletions
  /// removed and edits applied.
  List<({String key, SampleDish dish})> get _dishes => [
    for (final dish in [...SampleContent.menu, ..._added])
      if (!_deleted.contains(dish.name))
        (key: dish.name, dish: _edits[dish.name] ?? dish),
  ];

  /// Filtering runs here rather than in the list builder so the count in the
  /// subtitle and the rows below can never disagree.
  List<({String key, SampleDish dish})> get _visible {
    final label = SampleContent.menuFilters[_category].toLowerCase();
    final query = _query.trim().toLowerCase();

    return _dishes.where((entry) {
      final dish = entry.dish;
      final matchesQuery =
          query.isEmpty ||
          dish.name.toLowerCase().contains(query) ||
          dish.description.toLowerCase().contains(query);

      final matchesCategory = switch (label) {
        'vegan' => dish.tag?.toLowerCase() == 'vegan',
        'curry dishes' => dish.name.toLowerCase().contains('curry'),
        'main dishes' => dish.tag?.toLowerCase() != 'vegan',
        _ => true,
      };

      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _editDish(String key, SampleDish dish) async {
    final result = await showDishEditor(context: context, dish: dish);
    if (result == null || !mounted) return;
    // The edit is now applied rather than merely announced: this used to show
    // "updated" and change nothing.
    setState(() => _edits[key] = result);
    showAppSnack(context, '${result.name} updated.');
  }

  Future<void> _addDish() async {
    final result = await showDishEditor(context: context);
    if (result != null && mounted) {
      setState(() => _added.add(result));
      showAppSnack(context, '${result.name} added to the menu.');
    }
  }

  /// Confirms, then removes — with undo, because a mistake here takes a dish
  /// off the menu mid-service.
  Future<void> _deleteDish(String key, SampleDish dish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${dish.name}?'),
        content: const Text(
          'It comes off the menu straight away. You can undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.orderColors.overdue,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    AppHaptics.commit();
    // Start the fold. The row leaves state in `_finishDelete`, once the gap
    // has actually closed.
    setState(() => _collapsing = key);

    showAppSnack(
      context,
      '${dish.name} deleted.',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          // Works whether the fold is still running or already finished: one
          // reopens the row, the other puts it back.
          setState(() {
            _collapsing = null;
            _deleted.remove(key);
          });
        },
      ),
    );
  }

  void _finishDelete(String key) {
    if (!mounted || _collapsing != key) return;
    setState(() {
      _deleted.add(key);
      _collapsing = null;
    });
  }

  void _setAvailability(String key, {required bool available}) {
    setState(() {
      available ? _unavailable.remove(key) : _unavailable.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final available = _dishes.length - _unavailable.length;

    return Scaffold(
      appBar: buildAdminAppBar(context),
      // The frame puts a 46pt FAB at the bottom right rather than an "Add"
      // button in the header, which is where this screen had it.
      //
      // Lifted clear of the tab bar. Scaffold anchors a FAB to its own bottom
      // edge, and the shell's bar is an overlay in a Stack above this screen
      // rather than a `Scaffold.bottomNavigationBar` — so the FAB sat directly
      // underneath it, invisible and untappable. The shell reports the bar's
      // height as bottom padding, which is exactly the offset needed.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: SizedBox(
          width: 46,
          height: 46,
          child: FloatingActionButton(
            onPressed: () {
              AppHaptics.commit();
              _addDish();
            },
            tooltip: 'Add a dish to the menu',
            child: const Icon(Icons.add, size: AppIconSize.xl),
          ),
        ),
      ),
      body: Column(
        children: [
          _SearchAndFilter(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
          ).reveal(),
          const SizedBox(height: AppSpacing.x4),
          _CategoryStrip(
            selected: _category,
            onSelected: (index) => setState(() => _category = index),
          ).revealItem(1),
          const SizedBox(height: AppSpacing.x4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$available of ${_dishes.length} dishes available tonight.',
                    style: context.texts.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).revealItem(2),
          const SizedBox(height: AppSpacing.x3),
          Expanded(
            child: visible.isEmpty
                ? const _NoDishes().reveal()
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      0,
                      AppSpacing.gutter,
                      // Clear the FAB as well as the tab bar.
                      AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.x8),
                    itemBuilder: (context, position) {
                      final entry = visible[position];
                      return Collapse(
                        collapsed: _collapsing == entry.key,
                        onCollapsed: () => _finishDelete(entry.key),
                        child: _DishCard(
                          // Keyed so a delete or a rename can't hand this card's
                          // state to the dish that took its place.
                          key: ValueKey(entry.key),
                          dish: entry.dish,
                          available: !_unavailable.contains(entry.key),
                          onAvailabilityChanged: (value) =>
                              _setAvailability(entry.key, available: value),
                          onEdit: () => _editDish(entry.key, entry.dish),
                          onDelete: () => _deleteDish(entry.key, entry.dish),
                        ),
                      ).revealItem(position, duration: Motion.fast);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The frame's 44pt row: a search input with a leading glyph, and a separate
/// 36pt filter button set off to the right of it.
class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search menu...',
                  prefixIcon: const Icon(Icons.search, size: AppIconSize.lg),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: AppIconSize.md),
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          // Filters have no designed panel behind them, so this states its
          // own absence rather than opening an empty sheet.
          SizedBox(
            width: 36,
            height: 44,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.tune, size: AppIconSize.lg),
              tooltip: 'More filters',
              onPressed: () =>
                  showAppSnack(context, 'Filter options are not designed yet.'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The frame carries five category pills. Their labels are not recoverable
/// from metadata — only their widths — so this uses the filter set already
/// documented elsewhere in the app from the same design file.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
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

enum _DishAction { edit, delete }

/// One dish, laid out as the frame's 114pt item: 80pt thumbnail, then name and
/// price on one line, a single-line description under it, and tag pills below
/// that. The trailing control is an overflow menu, not the pencil this screen
/// used to show — the frame's glyph is a 4×16 vertical ellipsis.
class _DishCard extends StatelessWidget {
  const _DishCard({
    super.key,
    required this.dish,
    required this.available,
    required this.onAvailabilityChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final SampleDish dish;
  final bool available;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: context.motion.fade(Motion.fast),
      opacity: available ? 1 : 0.62,
      child: AppSurface.row(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 80,
                height: 80,
                child: DishImage(name: dish.name, imageUrl: dish.imageUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
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
                          style: context.texts.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      // Flexible so the pair can share a narrow card: the
                      // switch and thumbnail leave this column under 100pt on
                      // a 320pt phone.
                      Flexible(
                        child: Text(
                          dish.formattedPrice,
                          style: AppTypography.money(
                            scheme.primary,
                            size: MoneySize.compact,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  // One line in the frame, so it truncates rather than
                  // reflowing the card to a taller shape.
                  Text(
                    dish.description,
                    style: context.texts.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  _Tags(dish: dish, available: available),
                ],
              ),
            ),
            // Availability is a switch on the row rather than an item in the
            // overflow. The frame has no switch here, but taking a dish off
            // the menu mid-service is the one thing this screen exists to do
            // quickly — burying it behind a menu costs two taps and hides the
            // current state. Stacked above the overflow so it competes with
            // the dish name for height rather than width.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: available,
                  // Shrink-wrapped so the switch doesn't claim a 48pt tap
                  // target's worth of extra width on a 320pt phone.
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    AppHaptics.toggle();
                    onAvailabilityChanged(value);
                  },
                ),
                // Editing and deleting live behind the overflow. Deleting in
                // particular should not be one stray tap away from a row the
                // kitchen is scrolling past.
                SizedBox(
                  width: 24,
                  height: 28,
                  child: PopupMenuButton<_DishAction>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Actions for ${dish.name}',
                    icon: Icon(
                      Icons.more_vert,
                      size: AppIconSize.lg,
                      color: context.surfaces.inkSoft,
                    ),
                    onSelected: (action) => switch (action) {
                      _DishAction.edit => onEdit(),
                      _DishAction.delete => onDelete(),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<_DishAction>(
                        value: _DishAction.edit,
                        child: Text('Edit dish'),
                      ),
                      PopupMenuItem<_DishAction>(
                        value: _DishAction.delete,
                        child: Text(
                          'Delete dish',
                          style: TextStyle(color: context.orderColors.overdue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The frame shows one or two pills per item, the last of them outlined rather
/// than filled.
///
/// Availability used to take the outlined slot; the switch on the row now says
/// it plainly, so repeating it as a pill would be two controls for one fact.
class _Tags extends StatelessWidget {
  const _Tags({required this.dish, required this.available});

  final SampleDish dish;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final tag = dish.tag;

    // Both branches flexible: a tag like "Authentic Sri Lankan" and the
    // fallback label are each wider than this column gets on a 320pt phone.
    return Row(
      children: [
        Flexible(
          child: tag != null
              ? AppChip(
                  label: tag,
                  foreground: Theme.of(context).colorScheme.primary,
                  background: AppColors.crimson50,
                )
              : AppChip.outlined(
                  label: available ? 'On the menu' : 'Off tonight',
                ),
        ),
      ],
    );
  }
}

/// The design file has no empty state for any screen; this is invented, on the
/// same reasoning as the one on the customer menu.
class _NoDishes extends StatelessWidget {
  const _NoDishes();

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
              'Nothing on this filter',
              style: context.texts.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Try another category, or clear the search.',
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
