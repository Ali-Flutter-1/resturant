import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/order_row.dart';
import '../../../shared/widgets/status_pill.dart';
import 'order_actions_sheet.dart';

/// Staff-facing snapshot of the current service.
///
/// The content below is hard-coded for layout purposes only — there is no
/// repository, data source or mock service behind it. When the API contract
/// arrives this widget takes its values from a bloc and nothing else here
/// needs to change.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.onViewAll});
  final VoidCallback? onViewAll;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _statusOverrides = <String, OrderStatus>{};

  OrderStatus _statusOf(
    ({
      String amount,
      String destination,
      String detail,
      String reference,
      OrderStatus status,
    })
    order,
  ) => _statusOverrides[order.reference] ?? order.status;

  Future<void> _openOrder(
    ({
      String amount,
      String destination,
      String detail,
      String reference,
      OrderStatus status,
    })
    order,
  ) async {
    final next = await showOrderActionsSheet(
      context: context,
      reference: order.reference,
      destination: order.destination,
      amount: order.amount,
      status: _statusOf(order),
    );
    if (next != null && mounted) {
      setState(() => _statusOverrides[order.reference] = next);
    }
  }

  static const _recentOrders = [
    (
      reference: '#042',
      destination: 'Table 4',
      detail: '2 items · 5 mins ago',
      amount: '£28.50',
      status: OrderStatus.preparing,
    ),
    (
      reference: '#041',
      destination: 'Takeaway',
      detail: '4 items · 12 mins ago',
      amount: '£45.00',
      status: OrderStatus.ready,
    ),
    (
      reference: '#040',
      destination: 'Table 12',
      detail: '1 item · 25 mins ago',
      amount: '£8.00',
      status: OrderStatus.served,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAdminAppBar(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x2,
          AppSpacing.gutter,
          AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text('Dashboard Overview', style: context.texts.headlineLarge)
              .animate()
              .fadeIn(duration: Motion.moderate)
              .slideY(begin: 0.12, end: 0, curve: Motion.enter),
          const SizedBox(height: AppSpacing.x1),
          Text(
            "Today's snapshot for T's Café.",
            style: context.texts.bodyMedium,
          ).animate().fadeIn(delay: 80.ms, duration: Motion.moderate),
          const SizedBox(height: AppSpacing.x6),

          const MetricCard(
                caption: 'Total Revenue',
                value: '£24,500.00',
                icon: Icons.currency_pound,
                delta: '+12%',
              )
              .animate()
              .fadeIn(delay: 140.ms, duration: Motion.moderate)
              .slideY(begin: 0.15, end: 0, curve: Motion.enter),
          const SizedBox(height: AppSpacing.x3),

          Row(
                children: [
                  Expanded(
                    child: const MetricCard(
                      caption: 'Total Orders',
                      value: '1,248',
                      icon: Icons.shopping_bag_outlined,
                      valueSize: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: const MetricCard(
                      caption: 'Active Tables',
                      value: '14/20',
                      icon: Icons.chair_outlined,
                      valueSize: 26,
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 220.ms, duration: Motion.moderate)
              .slideY(begin: 0.15, end: 0, curve: Motion.enter),

          const SizedBox(height: AppSpacing.x8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Recent Orders', style: context.texts.headlineLarge),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Text('View All'),
              ),
            ],
          ).animate().fadeIn(delay: 300.ms, duration: Motion.moderate),
          const SizedBox(height: AppSpacing.x3),

          for (final (index, order) in _recentOrders.indexed) ...[
            OrderRow(
                  reference: order.reference,
                  destination: order.destination,
                  detail: order.detail,
                  amount: order.amount,
                  status: _statusOf(order),
                  onTap: () => _openOrder(order),
                )
                .animate()
                .fadeIn(
                  delay: 340.ms + Motion.staggerFor(index),
                  duration: Motion.quick,
                )
                .slideX(begin: 0.06, end: 0, curve: Motion.enter),
            if (index != _recentOrders.length - 1)
              const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}
