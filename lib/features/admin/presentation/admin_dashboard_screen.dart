import 'package:flutter/material.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/order_row.dart';
import '../../../shared/widgets/status_pill.dart';
import 'order_actions_sheet.dart';

/// Thousands separators, so a counting figure doesn't lurch as it crosses a
/// power of ten.
String _grouped(double value) => value.round().toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String _money(double value) => '£${_grouped(value)}.00';

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
          Text(
            'Dashboard Overview',
            style: context.texts.headlineLarge,
          ).reveal(),
          const SizedBox(height: AppSpacing.x1),
          Text(
            "Today's snapshot for T's Café.",
            style: context.texts.bodyMedium,
          ).revealItem(1),
          const SizedBox(height: AppSpacing.x6),

          MetricCard(
            caption: 'Total Revenue',
            value: '£24,500.00',
            // Takings are the figure the eye goes to first, and watching one
            // climb reads its scale before a single digit has been parsed.
            countTo: 24500,
            countFormat: _money,
            icon: Icons.currency_pound,
            delta: '+12%',
          ).revealItem(2),
          const SizedBox(height: AppSpacing.x3),

          Row(
            children: [
              Expanded(
                child: MetricCard(
                  caption: 'Total Orders',
                  value: '1,248',
                  countTo: 1248,
                  countFormat: _grouped,
                  icon: Icons.shopping_bag_outlined,
                  valueSize: MoneySize.large,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: const MetricCard(
                  caption: 'Active Tables',
                  value: '14/20',
                  icon: Icons.chair_outlined,
                  valueSize: MoneySize.large,
                ),
              ),
            ],
          ).revealItem(3),

          const SizedBox(height: AppSpacing.x8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Recent Orders',
                  style: context.texts.headlineLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Text('View All'),
              ),
            ],
          ).revealItem(4),
          const SizedBox(height: AppSpacing.x3),

          for (final (index, order) in _recentOrders.indexed) ...[
            OrderRow(
              reference: order.reference,
              destination: order.destination,
              detail: order.detail,
              amount: order.amount,
              status: _statusOf(order),
              onTap: () => _openOrder(order),
            ).revealItem(
              index,
              after: Motion.staggerFor(5),
              duration: Motion.fast,
              direction: AxisDirection.left,
            ),
            if (index != _recentOrders.length - 1)
              const SizedBox(height: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}
