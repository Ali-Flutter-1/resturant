import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/customer_order.dart';

/// Colour and glyph for a customer-facing order status.
///
/// Reuses the same four state colours the staff screens use — see
/// [OrderStateColors] — so "ready" is the same green on both sides of the app.
/// The mapping lives here rather than on the enum because the enum is domain and
/// knows nothing about themes.
extension CustomerOrderStatusPalette on CustomerOrderStatus {
  Color foreground(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      CustomerOrderStatus.placed ||
      CustomerOrderStatus.preparing => c.preparing,
      CustomerOrderStatus.ready ||
      CustomerOrderStatus.outForDelivery => c.ready,
      CustomerOrderStatus.completed => c.served,
      CustomerOrderStatus.cancelled => c.overdue,
    };
  }

  Color container(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      CustomerOrderStatus.placed ||
      CustomerOrderStatus.preparing => c.preparingContainer,
      CustomerOrderStatus.ready ||
      CustomerOrderStatus.outForDelivery => c.readyContainer,
      CustomerOrderStatus.completed => c.servedContainer,
      CustomerOrderStatus.cancelled => c.overdueContainer,
    };
  }

  /// The glyph for this stage. Each one names the thing that is happening, so
  /// the tracker reads at a glance without the labels.
  IconData get icon => switch (this) {
    CustomerOrderStatus.placed => Icons.receipt_long_outlined,
    CustomerOrderStatus.preparing => Icons.outdoor_grill_outlined,
    CustomerOrderStatus.ready => Icons.shopping_bag_outlined,
    CustomerOrderStatus.outForDelivery => Icons.delivery_dining_outlined,
    CustomerOrderStatus.completed => Icons.check_circle_outline,
    CustomerOrderStatus.cancelled => Icons.cancel_outlined,
  };
}
