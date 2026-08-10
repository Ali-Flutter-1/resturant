import 'package:flutter/material.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/status_pill.dart';
import 'order_actions_sheet.dart';

/// The live order queue.
///
/// Transcribed from "Admin Mobile: Manage Orders (Polished)" (`1:3482`), from
/// the frame's *metadata* only — the Figma MCP quota on this plan allows no
/// more than a call or two, so geometry and structure are the design's while
/// every colour and weight is this app's existing token, inferred rather than
/// read off the frame. Treat the styling as unverified.
///
/// The frame replaces this screen's filter chips and compact rows with one
/// expanded card per order: a 4pt status stripe down the left edge, reference
/// and status chip on a line, destination, detail and amount, then the order's
/// line items and the actions that apply to it.
///
/// Two things in the frame are deliberately *not* adopted. Its cards are
/// labelled Pending / Preparing / Out for Delivery, which is a different
/// status vocabulary from this app's; changing that touches the dashboard, the
/// order row, the actions sheet and their tests, and the frame shows only
/// three of the states so the full set cannot be recovered from it. And the
/// per-card action buttons cannot express every transition, so tapping a card
/// still opens the actions sheet.
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

  /// The one transition a card's primary button offers. Anything else — going
  /// back, or marking an order late — stays in the actions sheet, which is why
  /// the card itself remains tappable.
  static OrderStatus? _advanceFrom(OrderStatus status) => switch (status) {
    OrderStatus.preparing => OrderStatus.ready,
    OrderStatus.overdue => OrderStatus.ready,
    OrderStatus.ready => OrderStatus.served,
    OrderStatus.served => null,
  };

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Orders',
                        style: context.texts.headlineLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        '${counts[OrderStatus.preparing]} in the kitchen, '
                        '${counts[OrderStatus.ready]} awaiting collection.',
                        style: context.texts.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                // The frame carries one small control here rather than a row
                // of chips, so filtering became a menu.
                _FilterButton(
                  selected: _filter,
                  onSelected: (s) => setState(() => _filter = s),
                ),
              ],
            ),
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
                        const SizedBox(height: AppSpacing.x4),
                    itemBuilder: (context, index) {
                      final order = _visible[index];
                      final status = _statusOf(order);
                      return _OrderCard(
                        reference: order.reference,
                        destination: order.destination,
                        detail: order.detail,
                        amount: order.amount,
                        status: status,
                        onTap: () => _openOrder(order),
                        onAdvance: _advanceFrom(status) == null
                            ? null
                            : () => setState(() {
                                _statusOverrides[order.reference] =
                                    _advanceFrom(status)!;
                              }),
                      ).revealItem(
                        index,
                        duration: Motion.fast,
                        direction: AxisDirection.left,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The frame's single trailing control, in place of a chip row.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.selected, required this.onSelected});

  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: PopupMenuButton<OrderStatus?>(
        tooltip: 'Filter by status',
        initialValue: selected,
        onSelected: (value) {
          AppHaptics.selection();
          onSelected(value);
        },
        itemBuilder: (context) => [
          const PopupMenuItem<OrderStatus?>(value: null, child: Text('All')),
          for (final status in OrderStatus.values)
            PopupMenuItem<OrderStatus?>(
              value: status,
              child: Text(status.label),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: context.surfaces.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list,
                size: AppIconSize.sm,
                color: context.surfaces.inkMuted,
              ),
              const SizedBox(width: AppSpacing.x1),
              Text(selected?.label ?? 'All', style: context.texts.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

/// One order as the frame draws it: a status stripe down the left edge, the
/// reference beside a status chip, destination, detail and amount, then — for
/// an order the kitchen has yet to finish — its line items, and the action
/// that moves it on.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.reference,
    required this.destination,
    required this.detail,
    required this.amount,
    required this.status,
    this.onTap,
    this.onAdvance,
  });

  final String reference;
  final String destination;
  final String detail;
  final String amount;
  final OrderStatus status;
  final VoidCallback? onTap;

  /// Null once the order is finished, which is when the frame's action row has
  /// nothing left to offer.
  final VoidCallback? onAdvance;

  /// The frame shows line items only on the card that still needs cooking.
  bool get _showsItems => status != OrderStatus.served;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settled = status == OrderStatus.served;

    return AnimatedOpacity(
      duration: context.motion.fade(Motion.fast),
      opacity: settled ? 0.72 : 1,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // A Stack rather than a stretched Row: inside a ListView the card's
          // height is unbounded, and `CrossAxisAlignment.stretch` cannot
          // resolve against that. The Stack takes its size from the padded
          // content and the stripe stretches to match.
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: AnimatedContainer(
                  duration: context.motion.fade(Motion.fast),
                  color: status.foreground(context),
                ),
              ),
              Padding(
                // Left padding clears the stripe.
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4 + 4,
                  AppSpacing.x4,
                  AppSpacing.x4,
                  AppSpacing.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // The frame's reference box is about five
                                  // characters wide, so it carries the bare
                                  // reference rather than "Order #042".
                                  Flexible(
                                    child: Text(
                                      reference,
                                      style: context.texts.labelLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.x2),
                                  Flexible(child: StatusPill(status: status)),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.x2),
                              Text(
                                destination,
                                style: context.texts.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.x1),
                              Text(
                                detail,
                                style: context.texts.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Text(
                          amount,
                          style: AppTypography.money(
                            scheme.onSurface,
                            size: MoneySize.small,
                          ),
                        ),
                      ],
                    ),
                    if (_showsItems) ...[
                      const SizedBox(height: AppSpacing.x3),
                      _LineItems(),
                    ],
                    if (onAdvance != null) ...[
                      const SizedBox(height: AppSpacing.x3),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onTap,
                              child: const Text('Change status'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                AppHaptics.commit();
                                onAdvance!();
                              },
                              child: Text(
                                'Mark ${_AdminOrdersScreenState._advanceFrom(status)!.label.toLowerCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tinted panel of line items inside a card.
///
/// The frame shows two rows here but names neither, so the copy is not
/// recoverable from metadata — this reuses the basket the rest of the app
/// previews with. Per-order line items will come from the API.
class _LineItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = SampleContent.basket.take(2);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.x2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity}× ${item.name}',
                    style: context.texts.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  '£${(item.price * item.quantity).toStringAsFixed(2)}',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
              size: AppIconSize.hero,
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
      ).reveal(),
    );
  }
}
