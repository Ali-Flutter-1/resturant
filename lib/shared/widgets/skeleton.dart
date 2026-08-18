import 'package:flutter/material.dart';

import '../../core/animations/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The pieces a loading placeholder is built from.
///
/// A skeleton is only worth having if it is the *shape of the thing that is
/// coming* — otherwise the page still jumps on arrival and the placeholder was
/// just a busy rectangle. So this is a small kit rather than one widget: each
/// screen assembles the shape of its own rows.
///
/// Every placeholder uses the same tinted ground, and one [Shimmer] wraps the
/// whole list so a single highlight sweeps the page as one surface. A sweep per
/// row reads as noise.
abstract final class Skeleton {
  /// A line of text.
  static Widget line({double width = double.infinity, double height = 12}) =>
      _Block(width: width, height: height, radius: AppRadius.xs);

  /// A square-ish thumbnail or avatar.
  static Widget box({
    double width = 56,
    double height = 56,
    double radius = AppRadius.sm,
  }) => _Block(width: width, height: height, radius: radius);

  static Widget circle(double diameter) =>
      _Block(width: diameter, height: diameter, radius: diameter / 2);

  /// Wraps [rows] in one shimmer and a non-scrollable list.
  ///
  /// Not scrollable on purpose: there is nothing to reach, and a placeholder
  /// that bounces under the finger reads as broken content.
  static Widget list({
    required int count,
    required Widget Function(BuildContext, int) itemBuilder,
    double spacing = AppSpacing.x3,
    EdgeInsetsGeometry? padding,

    /// Set when the placeholder sits inside another scrollable, which would
    /// otherwise give this list unbounded height and fail to lay out.
    bool shrinkWrap = false,
  }) => Shimmer(
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: shrinkWrap,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: itemBuilder,
    ),
  );
}

class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.surfaces.accentContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder rows shaped like a message in the contact inbox: a status dot, a
/// name and status, a subject, and two lines of the message.
class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({
    super.key,
    this.rows = 5,
    this.shrinkWrap = false,
  });

  final int rows;

  /// True where this sits inside another scrollable.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Skeleton.list(
      count: rows,
      shrinkWrap: shrinkWrap,
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: context.surfaces.restShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x1 + 2),
              child: Skeleton.circle(8),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Skeleton.line(width: 120, height: 14),
                      const Spacer(),
                      Skeleton.box(
                        width: 64,
                        height: 20,
                        radius: AppRadius.pill,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2 + 2),
                  Skeleton.line(width: 180),
                  const SizedBox(height: AppSpacing.x2),
                  Skeleton.line(),
                  const SizedBox(height: AppSpacing.x1 + 2),
                  Skeleton.line(width: 220),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like the profile screen: an avatar and name centred,
/// then a card of detail lines.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.x5,
        ),
        child: Column(
          children: [
            Skeleton.circle(88),
            const SizedBox(height: AppSpacing.x3),
            Skeleton.line(width: 160, height: 18),
            const SizedBox(height: AppSpacing.x2),
            Skeleton.line(width: 200),
            const SizedBox(height: AppSpacing.x3),
            Skeleton.box(width: 96, height: 24, radius: AppRadius.pill),
            const SizedBox(height: AppSpacing.x5),
            Container(
              padding: const EdgeInsets.all(AppSpacing.x4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: context.surfaces.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton.line(width: 120, height: 16),
                  const SizedBox(height: AppSpacing.x5),
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.x4),
                    Row(
                      children: [
                        Skeleton.line(width: 80),
                        const SizedBox(width: AppSpacing.x3),
                        Expanded(child: Skeleton.line()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like an order ticket: a number and status, a detail
/// line, and the advance button.
class OrderListSkeleton extends StatelessWidget {
  const OrderListSkeleton({super.key, this.rows = 4, this.shrinkWrap = false});

  final int rows;

  /// True where this sits inside another scrollable.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return Skeleton.list(
      count: rows,
      shrinkWrap: shrinkWrap,
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: context.surfaces.restShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Skeleton.line(width: 90, height: 14),
                const Spacer(),
                Skeleton.box(width: 72, height: 20, radius: AppRadius.pill),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
            Skeleton.line(width: 220),
            const SizedBox(height: AppSpacing.x3),
            Skeleton.box(
              width: double.infinity,
              height: 40,
              radius: AppRadius.md,
            ),
          ],
        ),
      ),
    );
  }
}
