import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/auth_cubit.dart';
import '../../cart/cart_cubit.dart';
import '../../orders/domain/order_quote.dart';
import '../../orders/domain/order_repository.dart';
import 'checkout_cubit.dart';

/// Pricing the basket, then placing the order.
///
/// Every figure on this screen comes from `POST /orders/quote` — the fee, the
/// minimum, the total. Nothing is computed locally, because the server is what
/// charges the customer and a total the app worked out is only ever a guess at
/// what it will say.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, this.onBack, this.onPlaceOrder});

  final VoidCallback? onBack;

  /// Called once an order exists, with its number, so the caller can leave the
  /// checkout behind.
  final void Function(String orderNumber)? onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CheckoutCubit(
        repository: context.read<OrderRepository>(),
        cart: context.read<CartCubit>(),
      )..quote(),
      child: _CheckoutView(onBack: onBack, onPlaceOrder: onPlaceOrder),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView({this.onBack, this.onPlaceOrder});

  final VoidCallback? onBack;
  final void Function(String orderNumber)? onPlaceOrder;

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  late final _name = TextEditingController();
  late final _phone = TextEditingController();
  final _address = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _postcode = TextEditingController();
  final _deliveryNotes = TextEditingController();
  final _customerNote = TextEditingController();

  Map<String, String> _localErrors = const {};

  @override
  void initState() {
    super.initState();
    // Prefilled from the signed-in account. Asking somebody their own name in an
    // app they are signed into is a form they have already filled in.
    final user = context.read<AuthCubit>().state.user;
    if (user != null) _name.text = user.displayName;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _address,
      _address2,
      _city,
      _postcode,
      _deliveryNotes,
      _customerNote,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _place() async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<CheckoutCubit>();
    final isDelivery = cubit.state.isDelivery;

    // Checked here so the common mistakes cost no round trip. The server checks
    // all of it again and its wording wins whenever the two disagree.
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) {
      errors['contact_name'] = 'We need a name for the order.';
    }
    if (_phone.text.trim().length < 7) {
      errors['contact_phone'] = 'Enter a phone number we can reach you on.';
    }
    if (isDelivery) {
      if (_address.text.trim().isEmpty) {
        errors['address_line1'] = 'Where are we delivering to?';
      }
      if (_city.text.trim().isEmpty) errors['city'] = 'Add the town or city.';
      if (_postcode.text.trim().isEmpty) {
        errors['postcode'] = 'Add the postcode.';
      }
    }

    setState(() => _localErrors = errors);
    if (errors.isNotEmpty) {
      AppHaptics.failure();
      return;
    }

    final failure = await cubit.place(
      contactName: _name.text,
      contactPhone: _phone.text,
      addressLine1: _address.text,
      addressLine2: _address2.text,
      city: _city.text,
      postcode: _postcode.text,
      deliveryNotes: _deliveryNotes.text,
      customerNote: _customerNote.text,
    );
    if (!mounted) return;

    if (failure != null) {
      AppHaptics.failure();
      // The API's own words. Nothing typed is lost, and the same idempotency key
      // is kept — so pressing the button again retries rather than duplicating.
      showAppSnack(context, failure.message, isError: true);
      return;
    }

    AppHaptics.success();
    final order = cubit.state.placedOrder;
    if (order != null) {
      showAppSnack(context, 'Order ${order.reference} placed.');
      widget.onPlaceOrder?.call(order.reference);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CheckoutCubit, CheckoutState>(
      builder: (context, state) {
        final cubit = context.read<CheckoutCubit>();
        final quote = state.quote;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Checkout'),
            // Null `onBack` yields to `automaticallyImplyLeading`, which
            // supplies a working BackButton whenever the route can pop.
            leading: widget.onBack == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                    tooltip: 'Back',
                  ),
          ),
          body: state.stage == CheckoutStage.failed && state.failure != null
              ? ApiErrorView(
                  failure: state.failure!,
                  onRetry: () => cubit.quote(),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.x4,
                    AppSpacing.gutter,
                    AppSpacing.x12,
                  ),
                  children: [
                    _MethodPicker(
                      isDelivery: state.isDelivery,
                      busy: state.stage == CheckoutStage.quoting,
                      onChanged: cubit.setDelivery,
                    ),
                    const SizedBox(height: AppSpacing.x5),

                    _Panel(
                      title: 'Who it is for',
                      child: Column(
                        children: [
                          _Field(
                            label: 'Name',
                            controller: _name,
                            hint: 'Ali Hassan',
                            textCapitalization: TextCapitalization.words,
                            error: _error(state, 'contact_name'),
                          ),
                          const SizedBox(height: AppSpacing.x3),
                          _Field(
                            label: 'Phone',
                            controller: _phone,
                            hint: '07700 900123',
                            keyboardType: TextInputType.phone,
                            // Digits and the punctuation a phone number uses —
                            // the API accepts nothing else.
                            formatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9 +()-]'),
                              ),
                              LengthLimitingTextInputFormatter(30),
                            ],
                            error: _error(state, 'contact_phone'),
                          ),
                        ],
                      ),
                    ),

                    if (state.isDelivery) ...[
                      const SizedBox(height: AppSpacing.x4),
                      _Panel(
                        title: 'Where to',
                        child: Column(
                          children: [
                            _Field(
                              label: 'Address',
                              controller: _address,
                              hint: '12 Example Street',
                              error: _error(state, 'address_line1'),
                            ),
                            const SizedBox(height: AppSpacing.x3),
                            _Field(
                              label: 'Flat, floor (optional)',
                              controller: _address2,
                              hint: 'Flat 4',
                              error: _error(state, 'address_line2'),
                            ),
                            const SizedBox(height: AppSpacing.x3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _Field(
                                    label: 'Town or city',
                                    controller: _city,
                                    hint: 'Manchester',
                                    error: _error(state, 'city'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.x3),
                                Expanded(
                                  child: _Field(
                                    label: 'Postcode',
                                    controller: _postcode,
                                    hint: 'M1 2AB',
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    formatters: [
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                    error: _error(state, 'postcode'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.x3),
                            _Field(
                              label: 'Delivery notes (optional)',
                              controller: _deliveryNotes,
                              hint: 'Gate code, which door…',
                              maxLines: 2,
                              error: _error(state, 'delivery_notes'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.x4),
                    _TimingPanel(state: state, onChanged: cubit.setSlot),

                    const SizedBox(height: AppSpacing.x4),
                    _Panel(
                      title: 'Anything else',
                      child: _Field(
                        label: 'Note for the restaurant (optional)',
                        controller: _customerNote,
                        hint: 'Please call on arrival',
                        maxLines: 2,
                        error: _error(state, 'customer_note'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x4),
                    _QuotePanel(
                      quote: quote,
                      isDelivery: state.isDelivery,
                      loading: state.stage == CheckoutStage.quoting,
                    ),

                    const SizedBox(height: AppSpacing.x5),
                    // Cash only, said plainly rather than offering a card option
                    // the API rejects with CARD_PAYMENT_UNAVAILABLE.
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: AppIconSize.lg,
                          color: context.surfaces.inkSoft,
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Expanded(
                          child: Text(
                            'Pay with cash on '
                            '${state.isDelivery ? 'delivery' : 'collection'}. '
                            'Card payments are coming.',
                            style: context.texts.bodySmall?.copyWith(
                              color: context.surfaces.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.x5),
                    _PlaceButton(
                      state: state,
                      onPressed: state.canPlace ? _place : null,
                    ),
                  ].revealStaggered(),
                ),
        );
      },
    );
  }

  /// The server's complaint about a field wins over the local one — it knows
  /// things the app cannot.
  String? _error(CheckoutState state, String field) =>
      state.fieldErrors[field] ?? _localErrors[field];
}

/// Delivery or collection.
class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.isDelivery,
    required this.busy,
    required this.onChanged,
  });

  final bool isDelivery;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodTile(
            icon: Icons.delivery_dining,
            label: 'Delivery',
            selected: isDelivery,
            onTap: busy ? null : () => onChanged(true),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: _MethodTile(
            icon: Icons.storefront_outlined,
            label: 'Collection',
            selected: !isDelivery,
            onTap: busy ? null : () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: context.motion.fade(Motion.fast),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : context.surfaces.ground,
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
                size: AppIconSize.xxl,
                color: selected ? scheme.primary : context.surfaces.inkSoft,
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(
                label,
                style: context.texts.titleMedium?.copyWith(
                  color: selected ? scheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// As soon as possible, or a time the kitchen can actually make.
///
/// Sixteen chips in a Wrap is what this was: a wall of numbers with no sense of
/// which were plausible. Now it is two choices, and picking a time opens a list —
/// so the common case (as soon as possible) is one tap and the rare one is not
/// competing with it.
class _TimingPanel extends StatelessWidget {
  const _TimingPanel({required this.state, required this.onChanged});

  final CheckoutState state;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final slots = state.selectableSlots;
    final chosen = state.requestedFor;
    final prep = state.prepMinutes;

    return _Panel(
      title: 'When',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The kitchen's own estimate, stated before the choice — it is the
          // reason some times are missing, and an unexplained gap reads as a bug.
          if (prep != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x3),
              child: Row(
                children: [
                  Icon(
                    Icons.soup_kitchen_outlined,
                    size: AppIconSize.sm,
                    color: context.surfaces.inkSoft,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'This order takes about $prep minutes to cook, so earlier '
                      'times are not offered.',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _TimeOption(
            label: 'As soon as possible',
            detail: prep == null
                ? 'We start as soon as the order lands'
                : 'Ready in roughly $prep minutes',
            selected: chosen == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(height: AppSpacing.x2),
          _TimeOption(
            label: chosen == null
                ? 'Choose a time'
                : 'At ${_slotLabel(chosen)}',
            detail: slots.isEmpty
                ? 'No later times available'
                : '${slots.length} '
                      '${slots.length == 1 ? 'time' : 'times'} available',
            selected: chosen != null,
            onTap: slots.isEmpty
                ? null
                : () => _pickSlot(context, slots, chosen, onChanged),
          ),

          if (state.everySlotTooSoon) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              // Said rather than left as an empty list: the customer has done
              // nothing wrong, and "as soon as possible" still works.
              'Every later time tonight is inside this order’s cooking time, so '
              'only as soon as possible is available.',
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _pickSlot(
    BuildContext context,
    List<String> slots,
    String? chosen,
    ValueChanged<String?> onChanged,
  ) {
    showAppSheet<void>(
      context: context,
      title: 'Choose a time',
      subtitle: 'The earliest the kitchen can have it ready.',
      child: Builder(
        builder: (sheetContext) => ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.x2 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          children: [
            for (final slot in slots)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  slot == chosen
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: slot == chosen
                      ? Theme.of(sheetContext).colorScheme.primary
                      : sheetContext.surfaces.inkSoft,
                ),
                title: Text(_slotLabel(slot)),
                subtitle: Text(_slotDay(slot)),
                onTap: () {
                  AppHaptics.selection();
                  onChanged(slot);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// The slot as a local time. What goes back to the API is the untouched string.
  static String _slotLabel(String iso) {
    final when = DateTime.tryParse(iso)?.toLocal();
    if (when == null) return iso;
    return '${when.hour.toString().padLeft(2, '0')}:'
        '${when.minute.toString().padLeft(2, '0')}';
  }

  /// Today or tomorrow, so an 00:30 slot is not mistaken for this morning.
  static String _slotDay(String iso) {
    final when = DateTime.tryParse(iso)?.toLocal();
    if (when == null) return '';
    final now = DateTime.now();
    final day = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = day.difference(today).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return '${when.day}/${when.month}';
  }
}

/// One of the two timing choices.
class _TimeOption extends StatelessWidget {
  const _TimeOption({
    required this.label,
    required this.detail,
    required this.selected,
    this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: context.motion.fade(Motion.fast),
          padding: const EdgeInsets.all(AppSpacing.x3),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? scheme.primary : context.surfaces.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: AppIconSize.xl,
                color: selected
                    ? scheme.primary
                    : enabled
                    ? context.surfaces.inkSoft
                    : context.surfaces.line,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.texts.titleMedium?.copyWith(
                        color: enabled ? null : context.surfaces.inkSoft,
                      ),
                    ),
                    Text(
                      detail,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled && !selected)
                Icon(
                  Icons.chevron_right,
                  size: AppIconSize.xl,
                  color: context.surfaces.inkSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The server's arithmetic.
class _QuotePanel extends StatelessWidget {
  const _QuotePanel({
    required this.quote,
    required this.isDelivery,
    required this.loading,
  });

  final OrderQuote? quote;
  final bool isDelivery;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (quote == null) {
      return _Panel(
        title: 'Your order',
        child: Text(
          loading ? 'Pricing your basket…' : 'Nothing priced yet.',
          style: context.texts.bodyMedium?.copyWith(
            color: context.surfaces.inkSoft,
          ),
        ),
      );
    }

    final priced = quote!;
    return _Panel(
      title: 'Your order',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in priced.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${line.quantity}×',
                    style: context.texts.titleMedium,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: context.texts.bodyLarge),
                      if (line.notes != null)
                        Text(
                          line.notes!,
                          style: context.texts.bodySmall?.copyWith(
                            color: context.surfaces.inkSoft,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  OrderQuote.formatPence(line.linePence),
                  style: context.texts.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x3),
          ],
          Divider(color: context.surfaces.line),
          _SummaryLine(label: 'Subtotal', value: priced.formattedSubtotal),
          if (isDelivery)
            _SummaryLine(label: 'Delivery', value: priced.formattedFee),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Expanded(child: Text('Total', style: context.texts.titleLarge)),
              Text(
                priced.formattedTotal,
                style: AppTypography.money(scheme.onSurface),
              ),
            ],
          ),
          if (!priced.meetsMinimum) ...[
            const SizedBox(height: AppSpacing.x3),
            // The exact shortfall, because "minimum not met" leaves the customer
            // to do the arithmetic. The delivery fee does not count towards it.
            Container(
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: context.orderColors.overdueContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: AppIconSize.md,
                    color: context.orderColors.overdue,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'Add ${priced.formattedShortfall} more to reach the '
                      '${OrderQuote.formatPence(priced.minimumOrderPence)} '
                      'delivery minimum.',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.orderColors.overdue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.texts.bodyMedium?.copyWith(
                color: context.surfaces.inkMuted,
              ),
            ),
          ),
          Text(value, style: context.texts.bodyMedium),
        ],
      ),
    );
  }
}

class _PlaceButton extends StatelessWidget {
  const _PlaceButton({required this.state, this.onPressed});

  final CheckoutState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final submitting = state.stage == CheckoutStage.submitting;
    final quote = state.quote;

    return FilledButton(
      // Disabled while in flight, so a double tap cannot become two attempts —
      // the idempotency key would catch it, but not asking is better.
      onPressed: submitting ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: Text(
        submitting
            ? 'Placing your order…'
            : quote == null
            ? 'Place order'
            : 'Place order · ${quote.formattedTotal}',
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface.panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.texts.titleLarge),
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

/// A labelled field with a slot for the API's complaint about it.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.formatters,
    this.error,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final List<TextInputFormatter>? formatters;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.bodySmall),
        const SizedBox(height: AppSpacing.x1),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          inputFormatters: formatters,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            // Only the border turns: recolouring the whole field makes one wrong
            // character look like a failure of the form.
            enabledBorder: error == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colours.overdue),
                  ),
          ),
        ),
        AnimatedSize(
          duration: context.motion.move(Motion.fast),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x1),
                  child: Text(
                    error!,
                    style: context.texts.bodySmall?.copyWith(
                      color: colours.overdue,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
