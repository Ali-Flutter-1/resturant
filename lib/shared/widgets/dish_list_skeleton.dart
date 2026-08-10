import 'package:flutter/material.dart';

import '../../core/animations/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Stand-in rows shown while the menu loads.
///
/// Shaped like the real cards rather than being a spinner in the middle of the
/// screen: the page doesn't reflow when the dishes land, and the user can see
/// what is coming and roughly how much of it.
///
/// One [Shimmer] wraps the whole list, so a single highlight sweeps the page as
/// one surface. A sweep per row reads as noise.
class DishListSkeleton extends StatelessWidget {
  const DishListSkeleton({super.key, this.rows = 4, this.imageHeight = 168});

  final int rows;

  /// Matches the real card's photograph, so nothing shifts on arrival.
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        // Not scrollable: there is nothing to reach, and a skeleton that
        // bounces under the finger reads as broken content.
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x4),
        itemBuilder: (context, _) => _SkeletonCard(imageHeight: imageHeight),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.imageHeight});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final block = context.surfaces.lineFirm;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: imageHeight, color: block),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bar(width: 180, color: block),
                const SizedBox(height: AppSpacing.x2),
                _Bar(width: double.infinity, height: 12, color: block),
                const SizedBox(height: AppSpacing.x1),
                _Bar(width: 220, height: 12, color: block),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color, this.height = 16});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
  );
}
