import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/order_row.dart';
import '../../../shared/widgets/status_pill.dart';
import 'order_actions_sheet.dart';

/// The live order queue.
///
/// NOT transcribed from Figma — the Figma MCP quota was exhausted before the
/// "Admin Mobile: Manage Orders (Polished)" frame (`1:3482`) could be read.
/// This is built from the design language the Dashboard establishes, so it is
/// internally consistent but unverified. Check it against the frame before
/// treating it as final.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  OrderStatus? _filter;

  /// Status changes made in this session. The list itself is const preview
  /// content, so overrides live beside it rather than mutating it.
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

  static const _orders = [
    (
      reference: '#042',
      destination: 'Table 4',
      detail: '2 items · 5 mins ago',
      amount: '£28.50',
      status: OrderStatus.preparing,
    ),
    (
      reference: '#043',
      destination: 'Table 9',
      detail: '3 items · 2 mins ago',
      amount: '£52.00',
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
      reference: '#038',
      destination: 'Delivery · SW1A',
      detail: '2 items · 58 mins ago',
      amount: '£31.00',
      status: OrderStatus.overdue,
    ),
    (
      reference: '#040',
      destination: 'Table 12',
      detail: '1 item · 25 mins ago',
      amount: '£8.00',
      status: OrderStatus.served,
    ),
  ];

  List<
    ({
      String amount,
      String destination,
      String detail,
      String reference,
      OrderStatus status,
    })
  >
  get _visible => _filter == null
      ? _orders
      : _orders.where((o) => o.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final counts = <OrderStatus, int>{
      for (final status in OrderStatus.values)
        status: _orders.where((o) => _statusOf(o) == status).length,
    };

    return Scaffold(
      appBar: buildAdminAppBar(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.x2,
              AppSpacing.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Orders', style: context.texts.headlineLarge),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '${counts[OrderStatus.preparing]} in the kitchen, '
                  '${counts[OrderStatus.ready]} awaiting collection.',
                  style: context.texts.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          _StatusFilters(
            selected: _filter,
            counts: counts,
            total: _orders.length,
            onSelected: (s) => setState(() => _filter = s),
          ),
          const SizedBox(height: AppSpacing.x4),
          Expanded(
            child: _visible.isEmpty
                ? _EmptyQueue(status: _filter)
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      0,
                      AppSpacing.gutter,
                      AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: _visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.x2),
                    itemBuilder: (context, index) {
                      final order = _visible[index];
                      return OrderRow(
                            reference: order.reference,
                            destination: order.destination,
                            detail: order.detail,
                            amount: order.amount,
                            status: _statusOf(order),
                            onTap: () => _openOrder(order),
                          )
                          .animate()
                          .fadeIn(
                            delay: Motion.staggerFor(index),
                            duration: Motion.quick,
                          )
                          .slideX(begin: 0.05, end: 0, curve: Motion.enter);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.selected,
    required this.counts,
    required this.total,
    required this.onSelected,
  });

  final OrderStatus? selected;
  final Map<OrderStatus, int> counts;
  final int total;
  final ValueChanged<OrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          _FilterChip(
            label: 'All',
            count: total,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final status in OrderStatus.values) ...[
            const SizedBox(width: AppSpacing.x2),
            _FilterChip(
              label: status.label,
              count: counts[status] ?? 0,
              colour: status.foreground(context),
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.colour,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = colour ?? scheme.primary;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? accent : context.surfaces.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                color: selected ? accent : context.surfaces.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.x1 + 2),
            Text(
              '$count',
              style: context.texts.labelSmall?.copyWith(
                color: selected ? accent : context.surfaces.inkSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design file contains no empty state for any screen. This is invented.
class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({this.status});

  final OrderStatus? status;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 44,
              color: context.surfaces.inkSoft,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              status == null
                  ? 'No orders yet'
                  : 'Nothing ${status!.label.toLowerCase()}',
              style: context.texts.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'New orders appear here the moment they are placed.',
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().fadeIn(duration: Motion.moderate),
    );
  }
}
