import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'status_pill.dart';

/// A single line in the orders queue.
///
/// State is encoded three ways — a left stripe for peripheral vision, a pill
/// for the explicit label, and recession for closed orders. In the Figma
/// design all rows carried identical weight, so a queue of twenty read as an
/// undifferentiated list.
class OrderRow extends StatelessWidget {
  const OrderRow({
    super.key,
    required this.reference,
    required this.destination,
    required this.detail,
    required this.amount,
    required this.status,
    this.onTap,
  });

  /// Short order reference, e.g. `#042`.
  final String reference;

  /// Where it goes — `Table 4`, `Takeaway`.
  final String destination;

  /// Item count and elapsed time, e.g. `2 items · 5 mins ago`.
  final String detail;

  /// Preformatted currency, e.g. `£28.50`.
  final String amount;

  final OrderStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    // Closed orders recede so the live ones carry the eye.
    final settled = status == OrderStatus.served;

    return AnimatedOpacity(
      duration: context.motion.fade(Motion.fast),
      opacity: settled ? 0.72 : 1,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  AppHaptics.toggle();
                  onTap!();
                },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: surfaces.restShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Severity stripe.
                    AnimatedContainer(
                      duration: context.motion.fade(Motion.fast),
                      width: 3,
                      color: status.foreground(context),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.x3 + 2),
                        child: Row(
                          children: [
                            _ReferenceBadge(reference: reference),
                            const SizedBox(width: AppSpacing.x3 + 2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    destination,
                                    style: context.texts.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    detail,
                                    style: context.texts.bodySmall?.copyWith(
                                      color: surfaces.inkSoft,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  amount,
                                  style: AppTypography.money(
                                    scheme.onSurface,
                                    size: MoneySize.small,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.x1 + 2),
                                StatusPill(status: status),
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
          ),
        ),
      ),
    );
  }
}

class _ReferenceBadge extends StatelessWidget {
  const _ReferenceBadge({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.surfaces.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        reference,
        style: AppTypography.money(
          Theme.of(context).colorScheme.onPrimaryContainer,
          size: MoneySize.compact,
        ),
      ),
    );
  }
}
