import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_chip.dart';

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

/// Status as a chip: a dot for peripheral vision, a word for certainty.
///
/// A thin wrapper over [AppChip] so status can't drift away from every other
/// chip in the app, which is exactly what had happened.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return AppChip.status(
      label: status.label,
      foreground: status.foreground(context),
      background: status.container(context),
    );
  }
}
