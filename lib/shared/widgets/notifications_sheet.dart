import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_sheet.dart';

/// The notifications list.
///
/// No frame for this exists in the design, and the content will come from the
/// API. Built so the bell is a working control rather than a decoration.
Future<void> showNotificationsSheet(BuildContext context) {
  return showAppSheet<void>(
    context: context,
    title: 'Notifications',
    subtitle: 'Recent activity on your account.',
    child: const _NotificationsList(),
  );
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList();

  static const _items = [
    (
      icon: Icons.local_shipping_outlined,
      title: 'Order #042 is on its way',
      detail: '5 minutes ago',
      unread: true,
    ),
    (
      icon: Icons.event_available_outlined,
      title: 'Reservation confirmed for Friday, 19:00',
      detail: '2 hours ago',
      unread: true,
    ),
    (
      icon: Icons.local_offer_outlined,
      title: '20% off Jaffna Crab Curry this week',
      detail: 'Yesterday',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpacing.x6),
      itemBuilder: (context, index) {
        final item = _items[index];
        final scheme = Theme.of(context).colorScheme;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.surfaces.accentContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                item.icon,
                size: AppIconSize.lg,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.texts.titleMedium),
                  const SizedBox(height: 2),
                  Text(item.detail, style: context.texts.bodySmall),
                ],
              ),
            ),
            if (item.unread)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        );
      },
    );
  }
}
