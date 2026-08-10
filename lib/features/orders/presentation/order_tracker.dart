import 'package:flutter/material.dart';

import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/customer_order.dart';
import 'order_status_palette.dart';

/// The four stops an order passes through, drawn as a progress track.
///
/// The line fills rather than the dots merely recolouring: a bar that grows is
/// the one shape everybody already reads as "how far along". Every part of it is
/// an implicit animation driven by the status alone, so when a refresh moves the
/// order on a stage the track animates to the new position by itself — there is
/// no separate "advance" call that could disagree with the data.
///
/// Cancelled orders never reach here: [CustomerOrderStatus.step] is null for
/// them and the caller draws a plain notice instead. A cancellation on a track
/// that only moves forwards would have to be drawn either as progress or as
/// step zero, and both would be a lie.
class OrderTracker extends StatelessWidget {
  const OrderTracker({super.key, required this.order});

  final CustomerOrder order;

  /// The middle stop is worded for how the order is coming: an order being
  /// collected is never "on its way".
  List<String> _labels() => [
    'Placed',
    'Cooking',
    order.isDelivery ? 'On its way' : 'Ready',
    order.isDelivery ? 'Delivered' : 'Collected',
  ];

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final surfaces = context.surfaces;
    final active = order.status.foreground(context);
    final step = order.status.step ?? 0;
    final labels = _labels();

    // The fraction of the track behind the current stop. Dots sit at the ends of
    // their segments, so with four stops the fill spans thirds.
    final progress = step / (CustomerOrderStatus.steps - 1);

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The rail, inset by half a dot at each end so it starts and ends
              // under the first and last dot rather than at the card's edge.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: surfaces.line,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: motion.move(Motion.slow),
                    curve: motion.emphasized,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: active,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < CustomerOrderStatus.steps; i++)
                    _Stop(
                      reached: i <= step,
                      isCurrent: i == step,
                      colour: active,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == labels.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    // Only the stage the order is actually at is emphasised.
                    // Bolding everything reached would make a finished order
                    // shout four times.
                    color: i == step ? active : surfaces.inkSoft,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// One stop on the track.
class _Stop extends StatelessWidget {
  const _Stop({
    required this.reached,
    required this.isCurrent,
    required this.colour,
  });

  final bool reached;
  final bool isCurrent;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: motion.move(Motion.base),
      curve: motion.standard,
      // The current stop is larger. Size is what the eye finds first, before it
      // has read a single label.
      width: isCurrent ? 26 : 18,
      height: isCurrent ? 26 : 18,
      decoration: BoxDecoration(
        color: reached ? colour : scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: reached ? colour : surfaces.line, width: 2),
        // A halo only on the live stop, so it lifts off the rail.
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: colour.withValues(alpha: 0.28),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: reached
          ? Icon(
              Icons.check,
              size: isCurrent ? AppIconSize.sm : AppIconSize.xs,
              color: scheme.surface,
            )
          : null,
    );
  }
}
