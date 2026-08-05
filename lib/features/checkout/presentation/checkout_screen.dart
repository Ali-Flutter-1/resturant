import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/cart/cart_cubit.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/app_sheet.dart';

enum _OrderMethod { delivery, collection }

enum _DeliveryTime { asap, scheduled }

enum _PaymentMethod { card, cash }

/// Order method, address, timing, payment, and what it comes to.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.onBack, this.onPlaceOrder});

  final VoidCallback? onBack;
  final VoidCallback? onPlaceOrder;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  _OrderMethod _method = _OrderMethod.delivery;
  _DeliveryTime _timing = _DeliveryTime.asap;
  _PaymentMethod _payment = _PaymentMethod.card;
  TimeOfDay? _scheduledFor;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledFor ?? const TimeOfDay(hour: 19, minute: 15),
    );
    if (picked != null) setState(() => _scheduledFor = picked);
  }

  void _placeOrder() {
    // Scheduling without a time would send the kitchen an order it cannot
    // plan, so it blocks submission the way a missing address would.
    if (_timing == _DeliveryTime.scheduled && _scheduledFor == null) {
      showAppSnack(context, 'Pick a delivery time first.', isError: true);
      return;
    }
    context.read<CartCubit>().clear();
    showAppSnack(
      context,
      'Order placed — £${SampleContent.basketTotal.toStringAsFixed(2)}.',
    );
    widget.onPlaceOrder?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
          tooltip: 'Back',
        ),
        title: const Text('Checkout'),
        centerTitle: false,
        titleTextStyle: context.texts.headlineLarge,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x2,
          AppSpacing.gutter,
          AppSpacing.x8,
        ),
        children:
            [
                  _Panel(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Order Method',
                    child: Row(
                      children: [
                        Expanded(
                          child: _SelectableTile(
                            icon: Icons.delivery_dining,
                            label: 'Delivery',
                            selected: _method == _OrderMethod.delivery,
                            onTap: () =>
                                setState(() => _method = _OrderMethod.delivery),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Expanded(
                          child: _SelectableTile(
                            icon: Icons.storefront,
                            label: 'Collection',
                            selected: _method == _OrderMethod.collection,
                            onTap: () => setState(
                              () => _method = _OrderMethod.collection,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Collection has no address to capture, so the whole panel goes.
                  AnimatedSize(
                    duration: Motion.moderate,
                    curve: Motion.standard,
                    child: _method == _OrderMethod.delivery
                        ? const _AddressPanel()
                        : const SizedBox(width: double.infinity),
                  ),

                  _Panel(
                    icon: Icons.schedule,
                    title: 'Delivery Time',
                    badge: '45 min minimum prep time',
                    child: Column(
                      children: [
                        _RadioRow(
                          icon: Icons.bolt,
                          title: 'ASAP',
                          subtitle: 'Est. ~45-60 mins',
                          selected: _timing == _DeliveryTime.asap,
                          onTap: () =>
                              setState(() => _timing = _DeliveryTime.asap),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        _RadioRow(
                          icon: Icons.calendar_month_outlined,
                          title: 'Schedule',
                          subtitle: 'Pick a later time',
                          selected: _timing == _DeliveryTime.scheduled,
                          onTap: () =>
                              setState(() => _timing = _DeliveryTime.scheduled),
                        ),
                        AnimatedSize(
                          duration: Motion.moderate,
                          curve: Motion.standard,
                          child: _timing == _DeliveryTime.scheduled
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.x3,
                                  ),
                                  child: _PlaceholderSelect(
                                    label: _scheduledFor == null
                                        ? 'Choose a time'
                                        : 'Today, '
                                              '${_scheduledFor!.format(context)}',
                                    isPlaceholder: _scheduledFor == null,
                                    onTap: _pickTime,
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),

                  _Panel(
                    icon: Icons.credit_card,
                    title: 'Payment Method',
                    child: Column(
                      children: [
                        _RadioRow(
                          icon: Icons.credit_card,
                          title: 'Credit / Debit Card (Online)',
                          selected: _payment == _PaymentMethod.card,
                          onTap: () =>
                              setState(() => _payment = _PaymentMethod.card),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        _RadioRow(
                          icon: Icons.payments_outlined,
                          title: 'Cash on Delivery',
                          selected: _payment == _PaymentMethod.cash,
                          onTap: () =>
                              setState(() => _payment = _PaymentMethod.cash),
                        ),
                      ],
                    ),
                  ),

                  const _OrderSummary(),
                ]
                .animate(interval: 60.ms)
                .fadeIn(duration: Motion.moderate)
                .slideY(begin: 0.06, end: 0, curve: Motion.enter),
      ),
      bottomNavigationBar: _PlaceOrderBar(onPlaceOrder: _placeOrder),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.badge,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.x4),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: context.surfaces.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.surfaces.inkMuted),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTypography.caption(context.surfaces.inkMuted),
                ),
              ),
              if (badge != null) _Badge(label: badge!),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          child,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colours.overdueContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 11, color: colours.overdue),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(color: colours.overdue),
          ),
        ],
      ),
    );
  }
}

class _AddressPanel extends StatelessWidget {
  const _AddressPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.location_on_outlined,
      title: 'Delivery Address',
      child: Column(
        children: [
          const _LabelledInput(
            label: 'Street Address',
            hint: '123 Heritage Lane',
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _LabelledInput(
                  label: 'Apt, Suite, etc.',
                  hint: 'Apt 4B',
                ),
              ),
              SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _LabelledInput(label: 'Postcode', hint: 'SW1A 1AA'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          const _LabelledInput(
            label: 'Delivery Instructions',
            hint: 'Leave at the front door...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _LabelledInput extends StatelessWidget {
  const _LabelledInput({
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.bodySmall),
        const SizedBox(height: AppSpacing.x1 + 2),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            fillColor: context.surfaces.ground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x3,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        decoration: BoxDecoration(
          color: selected
              ? context.surfaces.accentContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : context.surfaces.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? scheme.primary : context.surfaces.inkMuted,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              label,
              style: context.texts.titleMedium?.copyWith(
                color: selected ? scheme.primary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: selected
              ? context.surfaces.accentContainer.withValues(alpha: 0.6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : context.surfaces.line,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? scheme.primary : context.surfaces.inkMuted,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.texts.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: context.texts.bodySmall),
                  ],
                ],
              ),
            ),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: Motion.quick,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? scheme.primary : context.surfaces.lineFirm,
          width: selected ? 5 : 1.5,
        ),
      ),
    );
  }
}

class _PlaceholderSelect extends StatelessWidget {
  const _PlaceholderSelect({
    required this.label,
    required this.onTap,
    this.isPlaceholder = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: context.surfaces.ground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.surfaces.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.texts.bodyMedium?.copyWith(
                  color: isPlaceholder
                      ? null
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: context.surfaces.inkSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: context.surfaces.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: context.texts.headlineLarge),
          const SizedBox(height: AppSpacing.x4),
          for (final item in SampleContent.basket) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.surfaces.ground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: context.texts.labelSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: context.texts.titleMedium),
                      const SizedBox(height: 1),
                      Text(item.note, style: context.texts.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  '£${item.price.toStringAsFixed(2)}',
                  style: context.texts.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          const Divider(),
          const SizedBox(height: AppSpacing.x3),
          _SummaryLine(label: 'Subtotal', value: SampleContent.basketSubtotal),
          const SizedBox(height: AppSpacing.x2),
          const _SummaryLine(
            label: 'Delivery Fee',
            value: SampleContent.deliveryFee,
          ),
          const SizedBox(height: AppSpacing.x2),
          const _SummaryLine(
            label: 'Service Charge',
            value: SampleContent.serviceCharge,
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total', style: context.texts.headlineLarge),
              Text(
                '£${SampleContent.basketTotal.toStringAsFixed(2)}',
                style: AppTypography.money(scheme.primary, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.texts.bodyMedium?.copyWith(color: scheme.primary),
        ),
        Text(
          '£${value.toStringAsFixed(2)}',
          style: context.texts.bodyMedium?.copyWith(
            color: scheme.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({this.onPlaceOrder});

  final VoidCallback? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.x3,
        AppSpacing.gutter,
        AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: context.surfaces.line)),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: onPlaceOrder,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 15, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.x2),
              Flexible(
                child: Text(
                  'Place Order · '
                  '£${SampleContent.basketTotal.toStringAsFixed(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
