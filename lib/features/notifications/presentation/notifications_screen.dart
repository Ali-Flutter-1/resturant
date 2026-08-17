import 'package:flutter/material.dart';
// `flutter_bloc` re-exports provider's `context.read` and the exception it
// throws when nothing is in scope, so the package is not a direct dependency.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/session_refresh.dart';
import '../domain/app_notification.dart';
import '../domain/notification_repository.dart';
import 'notifications_cubit.dart';

/// Opens the inbox.
///
/// [onFollow] is what a tapped row does. Without one the tap still marks the
/// row read and leaves the user on the inbox — which is a real action on a
/// screen that already says what happened, not a dead control.
///
/// Wiring a destination needs the shell's tabs, so it is supplied from there
/// rather than guessed at here. See [NotificationTarget]: anything the payload
/// does not clearly identify stays on the inbox by design.
void openNotifications(
  BuildContext context, {
  void Function(NotificationPayload payload)? onFollow,
}) {
  Navigator.of(context).push(
    AppPageRoute<void>(
      builder: (_) => NotificationsScreen(onOpen: onFollow),
    ),
  );
}

/// The in-app inbox.
///
/// The durable half of notifications: whatever the operating system did or did
/// not show, this is the record. It is a screen rather than the sheet it
/// replaced because the list pages, and a sheet that grows past the height cap
/// clips its own contents.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.onOpen});

  /// Opens whatever the notification is about. Given a validated payload — the
  /// screen it lands on fetches the record itself, because a push carries an id
  /// and nothing else worth trusting.
  final void Function(NotificationPayload payload)? onOpen;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NotificationsCubit(repository: context.read<NotificationRepository>())
            ..load(),
      child: _NotificationsView(onOpen: onOpen),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({this.onOpen});

  final void Function(NotificationPayload payload)? onOpen;

  Future<void> _open(BuildContext context, AppNotification item) async {
    AppHaptics.selection();
    // Marked read on open, as the guide asks. Not on arrival — a notification
    // that shows up while the list is open has not been read yet.
    await context.read<NotificationsCubit>().markRead(item);
    if (!context.mounted) return;
    onOpen?.call(item.payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            buildWhen: (a, b) => a.hasUnread != b.hasUnread,
            builder: (context, state) => TextButton(
              onPressed: state.hasUnread
                  ? context.read<NotificationsCubit>().markAllRead
                  : null,
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          final cubit = context.read<NotificationsCubit>();

          if (state.status == InboxStatus.loading) {
            return const MessageListSkeleton();
          }
          if (state.status == InboxStatus.failure && state.failure != null) {
            return ApiErrorView(
              failure: state.failure!,
              onRetry: () => cubit.load(),
            );
          }
          if (state.items.isEmpty) return const _Empty();

          return RefreshIndicator(
            onRefresh: () =>
                refreshWithSession(context, () => cubit.load(silent: true)),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x4,
                AppSpacing.gutter,
                AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.x3),
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return Center(
                    child: state.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(AppSpacing.x3),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: cubit.loadMore,
                            child: const Text('Load more'),
                          ),
                  );
                }

                final item = state.items[index];
                return _NotificationRow(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: () => _open(context, item),
                ).revealItem(index, duration: Motion.fast);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({super.key, required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(
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
                  _iconFor(item.payload.event),
                  size: AppIconSize.lg,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: context.texts.titleMedium?.copyWith(
                        // Weight, not colour: an unread row must still be
                        // legible, and a bold line is the convention every
                        // inbox already uses.
                        fontWeight: item.isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.body, style: context.texts.bodySmall),
                    ],
                    if (item.createdAt != null) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        _ago(item.createdAt!),
                        style: context.texts.labelSmall?.copyWith(
                          color: context.surfaces.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.isUnread)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: AppSpacing.x2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationEvent event) => switch (event) {
    NotificationEvent.orderPreparing => Icons.soup_kitchen_outlined,
    NotificationEvent.orderReady => Icons.room_service_outlined,
    NotificationEvent.orderOutForDelivery => Icons.local_shipping_outlined,
    NotificationEvent.orderCompleted => Icons.check_circle_outline,
    NotificationEvent.orderRejected ||
    NotificationEvent.orderCancelled ||
    NotificationEvent.orderCancelledAdmin => Icons.do_not_disturb_on_outlined,
    NotificationEvent.orderPlacedAdmin => Icons.receipt_long_outlined,
    NotificationEvent.bookingConfirmed => Icons.event_available_outlined,
    NotificationEvent.bookingRequestedAdmin => Icons.event_note_outlined,
    NotificationEvent.bookingRejected ||
    NotificationEvent.bookingCancelled ||
    NotificationEvent.bookingCancelledAdmin ||
    NotificationEvent.bookingExpired ||
    NotificationEvent.bookingNoShow => Icons.event_busy_outlined,
    // An event this build has never heard of still gets a row and an icon.
    NotificationEvent.unknown => Icons.notifications_none,
  };

  static String _ago(DateTime when) {
    final gap = DateTime.now().difference(when);
    if (gap.inMinutes < 1) return 'Just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
    if (gap.inHours < 24) {
      return '${gap.inHours} ${gap.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (gap.inDays == 1) return 'Yesterday';
    if (gap.inDays < 7) return '${gap.inDays} days ago';
    return '${when.day}/${when.month}/${when.year}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: AppIconSize.hero,
                  color: context.surfaces.inkSoft,
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'Nothing yet',
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Updates about your orders and bookings will appear here.',
                  style: context.texts.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The bell, with its unread count.
///
/// Owns a cubit of its own so the badge is live wherever the bell sits, without
/// the surrounding screen having to know anything about notifications.
///
/// Draws nothing at all where no [NotificationRepository] is in scope — a screen
/// used standalone, or in a test. That is the honest outcome rather than a
/// fallback: a bell that cannot count anything and opens an inbox that cannot
/// load is exactly the decoration-shaped-like-a-control worth not shipping.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final NotificationRepository repository;
    try {
      repository = context.read<NotificationRepository>();
    } on ProviderNotFoundException {
      debugPrint(
        'NotificationBell: no NotificationRepository in scope, so no bell.',
      );
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => NotificationsCubit(repository: repository)..refreshBadge(),
      child: _BellButton(onOpen: onOpen),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = context.select((NotificationsCubit c) => c.state.unread);

    return IconButton(
      tooltip: 'Notifications',
      color: scheme.primary,
      onPressed: () {
        AppHaptics.toggle();
        onOpen();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0
                ? Icons.notifications
                : Icons.notifications_none_outlined,
          ),
          if (unread > 0)
            Positioned(
              right: -6,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: scheme.surface),
                ),
                child: Text(
                  // Past 99 the pill stops being a number and starts being a
                  // width problem.
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: AppTypography.badge(scheme.onPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
