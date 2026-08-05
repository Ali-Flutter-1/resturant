import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/app_sheet.dart';
import 'dish_editor_sheet.dart';
import '../../../shared/widgets/dish_image.dart';

/// What's on and what's off tonight.
///
/// NOT transcribed from Figma — the MCP quota was exhausted before
/// "Admin Mobile: Menu Management (Polished)" (`1:3368`) could be read. Built
/// on the Dashboard's design language; verify against the frame.
class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
  /// Indices of dishes taken off the menu for tonight.
  final _unavailable = <int>{3};

  /// Dishes added during this session, kept beside the const preview list.
  final _added = <SampleDish>[];

  List<SampleDish> get _dishes => [...SampleContent.menu, ..._added];

  Future<void> _editDish(SampleDish dish) async {
    final result = await showDishEditor(context: context, dish: dish);
    if (result != null && mounted) {
      showAppSnack(context, '${result.name} updated.');
    }
  }

  Future<void> _addDish() async {
    final result = await showDishEditor(context: context);
    if (result != null && mounted) {
      setState(() => _added.add(result));
      showAppSnack(context, '${result.name} added to the menu.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _dishes.length - _unavailable.length;

    return Scaffold(
      appBar: buildAdminAppBar(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x2,
          AppSpacing.gutter,
          AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Menu Management', style: context.texts.headlineLarge),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      '$available of ${_dishes.length} dishes '
                      'available tonight.',
                      style: context.texts.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              _AddDishButton(onPressed: _addDish),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),
          for (final (index, dish) in _dishes.indexed) ...[
            _DishRow(
                  name: dish.name,
                  price: dish.formattedPrice,
                  tag: dish.tag,
                  available: !_unavailable.contains(index),
                  onAvailabilityChanged: (on) => setState(() {
                    on ? _unavailable.remove(index) : _unavailable.add(index);
                  }),
                  onEdit: () => _editDish(dish),
                )
                .animate()
                .fadeIn(delay: Motion.staggerFor(index), duration: Motion.quick)
                .slideY(begin: 0.06, end: 0, curve: Motion.enter),
            if (index != _dishes.length - 1)
              const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

class _AddDishButton extends StatelessWidget {
  const _AddDishButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x2 + 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.x1 + 2),
              Text(
                'Add',
                style: context.texts.labelLarge?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.name,
    required this.price,
    required this.available,
    required this.onAvailabilityChanged,
    required this.onEdit,
    this.tag,
  });

  final String name;
  final String price;
  final String? tag;
  final bool available;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: Motion.quick,
      opacity: available ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: context.surfaces.restShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: DishImage(name: name),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: context.texts.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        price,
                        style: AppTypography.money(scheme.primary, size: 14),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: AppSpacing.x2),
                        Text('·', style: context.texts.bodySmall),
                        const SizedBox(width: AppSpacing.x2),
                        Text(tag!, style: context.texts.bodySmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              tooltip: 'Edit $name',
              color: context.surfaces.inkSoft,
            ),
            Switch(
              value: available,
              onChanged: (value) {
                AppHaptics.toggle();
                onAvailabilityChanged(value);
              },
              activeThumbColor: scheme.onPrimary,
              activeTrackColor: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
