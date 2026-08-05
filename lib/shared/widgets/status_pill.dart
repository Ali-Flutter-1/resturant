import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The lifecycle of an order, as the kitchen and counter see it.
enum OrderStatus {
  preparing('Preparing'),
  ready('Ready'),
  served('Served'),

  /// Past its target time. Not present in the Figma design — added because an
  /// order queue needs a way to say "this one is late".
  overdue('Overdue');

  const OrderStatus(this.label);
  final String label;
}

extension OrderStatusPalette on OrderStatus {
  Color foreground(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      OrderStatus.preparing => c.preparing,
      OrderStatus.ready => c.ready,
      OrderStatus.served => c.served,
      OrderStatus.overdue => c.overdue,
    };
  }

  Color container(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      OrderStatus.preparing => c.preparingContainer,
      OrderStatus.ready => c.readyContainer,
      OrderStatus.served => c.servedContainer,
      OrderStatus.overdue => c.overdueContainer,
    };
  }
}

/// Status as a pill: a dot for peripheral vision, a word for certainty.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final fg = status.foreground(context);

    return AnimatedContainer(
      duration: Motion.quick,
      curve: Motion.standard,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.container(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(
            status.label.toUpperCase(),
            style: context.texts.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.88,
            ),
          ),
        ],
      ),
    );
  }
}
