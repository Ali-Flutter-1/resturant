import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/dish_list_skeleton.dart';
import '../domain/customer_order.dart';
import '../domain/order_repository.dart';
import 'order_status_palette.dart';
import 'order_tracker.dart';
import 'orders_cubit.dart';

/// The customer's orders: what is happening now, and what happened before.
///
/// The screen is in two halves because the two questions are different. "Where
/// is my food?" is urgent and wants a tracker; "what did I order last time?" is
/// a list. Putting a live order into a uniform history list would bury the only
/// row the user opened the app to see.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key, this.onBrowseMenu});

  /// Offered from the empty state — a first-time customer has nothing to read
  /// here, so the screen's job is to send them somewhere useful.
  final VoidCallback? onBrowseMenu;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          OrdersCubit(repository: context.read<OrderRepository>())..load(),
      child: _MyOrdersView(onBrowseMenu: onBrowseMenu),
    );
  }
}

class _MyOrdersView extends StatefulWidget {
  const _MyOrdersView({this.onBrowseMenu});

  final VoidCallback? onBrowseMenu;

  @override
  State<_MyOrdersView> createState() => _MyOrdersViewState();
}

class _MyOrdersViewState extends State<_MyOrdersView> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // A live order changes without the user doing anything, and pull-to-refresh
    // is a poor answer to "is it out for delivery yet" — it asks the person
    // watching the screen to keep asking. Polling is silent, so the tracker
    // moves under them rather than blanking.
    //
    // Thirty seconds, and only while something is actually in progress: see the
    // listener below, which stops the timer the moment the last order settles.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<OrdersCubit>().load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _stopPollingIfSettled(OrdersState state) {
    if (state.status == OrdersStatus.ready && state.live.isEmpty) {
      _poll?.cancel();
      _poll = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) => _stopPollingIfSettled(state),
        builder: (context, state) {
          final cubit = context.read<OrdersCubit>();

          if (state.status == OrdersStatus.loading) {
            // The same card-shaped skeleton the menu uses, at tracker height:
            // the page doesn't reflow when the orders land.
            return const DishListSkeleton(rows: 3, imageHeight: 96);
          }

          if (state.status == OrdersStatus.failure && state.failure != null) {
            return ApiErrorView(
              failure: state.failure!,
              onRetry: () => cubit.load(),
            );
          }

          if (state.isEmpty) {
            return _NoOrdersYet(onBrowseMenu: widget.onBrowseMenu);
          }

          final live = state.live;
          final past = state.past;

          return RefreshIndicator(
            onRefresh: () => cubit.load(silent: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x4,
                AppSpacing.gutter,
                AppSpacing.x12,
              ),
              children: [
                if (live.isNotEmpty) ...[
                  _SectionHeading(
                    label: live.length == 1
                        ? 'Happening now'
                        : '${live.length} orders in progress',
                  ),
                  for (final order in live)
                    Padding(
                      key: ValueKey('live-${order.id}'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                      child: _LiveOrderCard(
                        order: order,
                        isCancelling: state.cancellingId == order.id,
                      ),
                    ),
                ],
                if (past.isNotEmpty) ...[
                  if (live.isNotEmpty) const SizedBox(height: AppSpacing.x4),
                  const _SectionHeading(label: 'Earlier orders'),
                  for (final order in past)
                    Padding(
                      key: ValueKey('past-${order.id}'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                      child: _PastOrderRow(order: order),
                    ),
                ],
              ].revealStaggered(),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(label, style: context.texts.headlineMedium),
    );
  }
}

/// An order still in progress: the tracker, what is in it, and the way out.
class _LiveOrderCard extends StatelessWidget {
  const _LiveOrderCard({required this.order, required this.isCancelling});

  final CustomerOrder order;
  final bool isCancelling;

  Future<void> _cancel(BuildContext context) async {
    final cubit = context.read<OrdersCubit>();
    // Asked before it happens, not undone afterwards. There is no un-cancelling
    // an order the kitchen has already stopped cooking.
    final confirmed = await showAppSheet<bool>(
      context: context,
      title: 'Cancel order ${order.reference}?',
      child: Builder(
        builder: (sheetContext) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This cannot be undone. If the kitchen has already started, we '
              'may not be able to cancel.',
              style: sheetContext.texts.bodyMedium?.copyWith(
                color: sheetContext.surfaces.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            PrimaryButton(
              label: 'Cancel this order',
              // Pops the sheet's own route, not the screen behind it — hence
              // the Builder: the enclosing context predates the sheet.
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: AppSpacing.x2),
            SecondaryButton(
              label: 'Keep my order',
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = await cubit.cancelOrder(order.id);
    if (!context.mounted) return;

    if (error == null) {
      AppHaptics.success();
      showAppSnack(context, 'Order ${order.reference} was cancelled.');
    } else {
      AppHaptics.failure();
      showAppSnack(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final colour = order.status.foreground(context);

    return AppSurface.panel(
      padding: const EdgeInsets.all(AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: order.status.container(context),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  order.status.icon,
                  size: AppIconSize.xl,
                  color: colour,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.statusLabel,
                      style: context.texts.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${order.reference} · ${_itemSummary(order)}',
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
              Text(
                order.formattedTotal,
                style: AppTypography.money(
                  Theme.of(context).colorScheme.onSurface,
                  size: MoneySize.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),

          OrderTracker(order: order),

          const SizedBox(height: AppSpacing.x4),
          Text(order.statusExplanation, style: context.texts.bodyMedium),

          if (order.estimatedReadyAt != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: AppIconSize.sm,
                  color: surfaces.inkSoft,
                ),
                const SizedBox(width: AppSpacing.x1 + 2),
                Text(
                  '${order.isDelivery ? 'Arriving' : 'Ready'} around '
                  '${_time(order.estimatedReadyAt!)}',
                  style: context.texts.bodySmall?.copyWith(
                    color: surfaces.inkSoft,
                  ),
                ),
              ],
            ),
          ],

          if (order.canCancel) ...[
            const SizedBox(height: AppSpacing.x4),
            // Quiet, not a primary button: cancelling is the rare choice on a
            // card whose main purpose is reassurance.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isCancelling ? null : () => _cancel(context),
                icon: isCancelling
                    ? const SizedBox(
                        width: AppIconSize.md,
                        height: AppIconSize.md,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: AppIconSize.md),
                label: Text(isCancelling ? 'Cancelling…' : 'Cancel order'),
                style: TextButton.styleFrom(
                  foregroundColor: context.orderColors.overdue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A finished order: one line, tappable for the receipt.
class _PastOrderRow extends StatelessWidget {
  const _PastOrderRow({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () async {
          AppHaptics.toggle();
          // The list endpoint sends no lines, so the receipt is fetched. If the
          // fetch fails the summary is shown anyway — a total and a date is
          // still most of a receipt, and an error sheet would be less.
          final cubit = context.read<OrdersCubit>();
          final detailed = await cubit.loadDetail(order.id);
          if (!context.mounted) return;
          _showReceipt(context, detailed ?? order);
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x3 + 2),
          child: Row(
            children: [
              Icon(
                order.status.icon,
                size: AppIconSize.xl,
                color: order.status.foreground(context),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order.reference,
                      style: context.texts.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (order.placedAt != null) _date(order.placedAt!),
                        _itemSummary(order),
                      ].join(' · '),
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
                    order.formattedTotal,
                    style: AppTypography.money(
                      scheme.onSurface,
                      size: MoneySize.small,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1 + 2),
                  AppChip.status(
                    label: order.statusLabel,
                    foreground: order.status.foreground(context),
                    background: order.status.container(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The receipt for a past order.
void _showReceipt(BuildContext context, CustomerOrder order) {
  showAppSheet<void>(
    context: context,
    title: 'Order ${order.reference}',
    // Padded and scrollable. It was a bare Column: no gutter, so the lines ran
    // to both edges, and no scroll, so a receipt with several items grew the
    // sheet to the height cap and then clipped the total off the bottom.
    child: Builder(
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.x2 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppChip.status(
                  label: order.statusLabel,
                  foreground: order.status.foreground(context),
                  background: order.status.container(context),
                ),
                const SizedBox(width: AppSpacing.x2),
                if (order.placedAt != null)
                  Text(
                    _date(order.placedAt!),
                    style: context.texts.bodySmall?.copyWith(
                      color: context.surfaces.inkSoft,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),

            if (order.items.isEmpty)
              // Only reached when the detail fetch failed, since the API always
              // sends lines on a single order. Saying so beats an empty gap that
              // reads as a rendering fault.
              Text(
                'Could not load the item breakdown. Pull to refresh and try '
                'again.',
                style: context.texts.bodyMedium?.copyWith(
                  color: context.surfaces.inkSoft,
                ),
              )
            else
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${item.quantity}×',
                          style: context.texts.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.dishName, style: context.texts.bodyLarge),
                            if (item.notes != null)
                              Text(
                                item.notes!,
                                style: context.texts.bodySmall?.copyWith(
                                  color: context.surfaces.inkSoft,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        '£${(item.linePence / 100).toStringAsFixed(2)}',
                        style: context.texts.bodyLarge,
                      ),
                    ],
                  ),
                ),

            Divider(height: AppSpacing.x6, color: context.surfaces.line),
            Row(
              children: [
                Expanded(child: Text('Total', style: context.texts.titleLarge)),
                Text(
                  order.formattedTotal,
                  style: AppTypography.money(
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Nothing ordered yet.
class _NoOrdersYet extends StatelessWidget {
  const _NoOrdersYet({this.onBrowseMenu});

  final VoidCallback? onBrowseMenu;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: AppIconSize.hero,
              color: context.surfaces.inkSoft,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text('No orders yet', style: context.texts.headlineMedium),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Your orders will appear here, and you can follow each one from '
              'the kitchen to your door.',
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: context.surfaces.inkMuted,
              ),
            ),
            if (onBrowseMenu != null) ...[
              const SizedBox(height: AppSpacing.x6),
              SecondaryButton(
                label: 'Browse the menu',
                onPressed: onBrowseMenu,
              ),
            ],
          ],
        ),
      ).reveal(),
    );
  }
}

String _itemSummary(CustomerOrder order) {
  final count = order.itemCount;
  if (count == 0) return order.isDelivery ? 'Delivery' : 'Collection';
  return '$count ${count == 1 ? 'item' : 'items'}'
      ' · ${order.isDelivery ? 'Delivery' : 'Collection'}';
}

/// A date a person can read. "Today" and "Yesterday" are what someone scanning
/// their recent orders is actually looking for.
String _date(DateTime when) {
  final now = DateTime.now();
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Today, ${_time(when)}';
  if (difference == 1) return 'Yesterday, ${_time(when)}';
  return '${when.day} ${_months[when.month - 1]}'
      '${when.year == now.year ? '' : ' ${when.year}'}';
}

String _time(DateTime when) =>
    '${when.hour.toString().padLeft(2, '0')}:'
    '${when.minute.toString().padLeft(2, '0')}';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
