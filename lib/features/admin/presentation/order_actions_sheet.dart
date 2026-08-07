import 'package:flutter/material.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/status_pill.dart';

/// Opens an order so staff can advance it through the kitchen.
///
/// Returns the status the user moved it to, or null if they dismissed the
/// sheet. The caller owns the state — this only reports the decision.
Future<OrderStatus?> showOrderActionsSheet({
  required BuildContext context,
  required String reference,
  required String destination,
  required String amount,
  required OrderStatus status,
}) {
  return showAppSheet<OrderStatus>(
    context: context,
    title: 'Order $reference',
    subtitle: '$destination · $amount',
    child: _OrderActions(status: status),
  );
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.status});

  final OrderStatus status;

  /// What this order can sensibly become next. A served order is finished;
  /// offering to move it back to "preparing" would invite mistakes.
  List<OrderStatus> get _transitions => switch (status) {
    OrderStatus.preparing => [OrderStatus.ready, OrderStatus.overdue],
    OrderStatus.ready => [OrderStatus.served, OrderStatus.overdue],
    OrderStatus.overdue => [OrderStatus.ready, OrderStatus.served],
    OrderStatus.served => [],
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CURRENT',
                style: AppTypography.caption(context.surfaces.inkSoft),
              ),
              const SizedBox(width: AppSpacing.x3),
              StatusPill(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.x6),

          if (_transitions.isEmpty)
            Text(
              'This order is complete. Nothing left to do.',
              style: context.texts.bodyLarge,
            )
          else ...[
            Text('Move to', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x3),
            for (final next in _transitions) ...[
              _TransitionButton(status: next),
              const SizedBox(height: AppSpacing.x3),
            ],
          ],
        ],
      ),
    );
  }
}

class _TransitionButton extends StatelessWidget {
  const _TransitionButton({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colour = status.foreground(context);

    return Material(
      color: status.container(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          AppHaptics.commit();
          Navigator.of(context).pop(status);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x4,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  status.label,
                  style: context.texts.titleMedium?.copyWith(color: colour),
                ),
              ),
              Icon(Icons.arrow_forward, size: AppIconSize.md, color: colour),
            ],
          ),
        ),
      ),
    );
  }
}
