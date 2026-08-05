import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// A headline figure on the admin dashboard.
///
/// The value is set in the display face with tabular figures, so a column of
/// these holds its alignment as the numbers change through service.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.caption,
    required this.value,
    required this.icon,
    this.delta,
    this.deltaIsPositive = true,
    this.valueSize = 30,
  });

  final String caption;
  final String value;
  final IconData icon;

  /// Change against the comparable prior period, e.g. `+12%`.
  final String? delta;
  final bool deltaIsPositive;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final orderColors = context.orderColors;
    final deltaColor = deltaIsPositive
        ? orderColors.ready
        : orderColors.overdue;
    final deltaBg = deltaIsPositive
        ? orderColors.readyContainer
        : orderColors.overdueContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4 + 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: surfaces.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: deltaBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    delta!,
                    style: context.texts.labelSmall?.copyWith(
                      color: deltaColor,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            caption.toUpperCase(),
            style: AppTypography.caption(surfaces.inkSoft),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            value,
            style: AppTypography.money(
              Theme.of(context).colorScheme.onSurface,
              size: valueSize,
              tabular: false,
            ),
          ),
        ],
      ),
    );
  }
}
