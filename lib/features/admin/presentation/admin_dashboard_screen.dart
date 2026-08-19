import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/admin_nav.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/page_body.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/session_refresh.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_cubit.dart';

/// The admin landing screen: takings, the live queue, and what needs attention.
///
/// One request powers all three sections. Everything here was hardcoded sample
/// content until now — three invented orders and a made-up revenue figure.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    this.onViewAll,
    this.onViewBookings,
    this.onViewMessages,
  });

  /// Opens the order queue. The dashboard adds no destinations of its own — it
  /// points at screens that already exist.
  final VoidCallback? onViewAll;
  final VoidCallback? onViewBookings;
  final VoidCallback? onViewMessages;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DashboardCubit(repository: context.read<DashboardRepository>())
            ..load(),
      child: _DashboardView(
        onViewAll: onViewAll,
        onViewBookings: onViewBookings,
        onViewMessages: onViewMessages,
      ),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView({
    this.onViewAll,
    this.onViewBookings,
    this.onViewMessages,
  });

  final VoidCallback? onViewAll;
  final VoidCallback? onViewBookings;
  final VoidCallback? onViewMessages;

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Refreshed on return to the foreground, and never on a timer. Push already
    // announces new orders, and one round trip when somebody looks at the screen
    // is cheaper and quieter than polling all day.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) context.read<DashboardCubit>().load();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAdminAppBar(context, title: 'Dashboard'),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final cubit = context.read<DashboardCubit>();

          if (state.status == DashboardStatus.loading) {
            return const MessageListSkeleton(rows: 4);
          }

          // A staff account, or an admin demoted mid-session. Not a retry —
          // signing in again produces the same role and the same refusal.
          if (state.isForbidden && state.summary == null) {
            return _NoAccess(message: state.failure!.message);
          }

          if (state.status == DashboardStatus.failure && state.failure != null) {
            return ApiErrorView(
              failure: state.failure!,
              onRetry: cubit.load,
            );
          }

          final summary = state.summary ?? const DashboardSummary();

          return RefreshIndicator(
            onRefresh: () => refreshWithSession(context, cubit.load),
            child: ListView(
              padding: pagePadding(
                context,
                top: AppSpacing.x4,
                bottom: AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
              ),
              children:
                  [
                    // Figures stay put through a failed refresh — zero revenue
                    // is a real number and must never stand in for "failed".
                    if (state.isStale) _StaleBanner(state: state),
                    _RevenueRow(revenue: summary.revenue),
                    const SizedBox(height: AppSpacing.x5),
                    _OrdersPanel(
                      orders: summary.orders,
                      onTap: widget.onViewAll,
                    ),
                    const SizedBox(height: AppSpacing.x5),
                    _AttentionPanel(
                      attention: summary.attention,
                      onBookings: widget.onViewBookings,
                      onMessages: widget.onViewMessages,
                    ),
                  ].revealStaggered(),
            ),
          );
        },
      ),
    );
  }
}

/// Takings. Three tiles, deliberately not compared to each other — a month can
/// start mid-week, so `today <= week <= month` is not guaranteed.
class _RevenueRow extends StatelessWidget {
  const _RevenueRow({required this.revenue});

  final RevenueTiles revenue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _RevenueTile(
            label: 'Today',
            pence: revenue.todayPence,
            emphasise: true,
          ),
          _RevenueTile(label: 'This week', pence: revenue.thisWeekPence),
          _RevenueTile(label: 'This month', pence: revenue.thisMonthPence),
        ];

        // Side by side where there is room; stacked on a narrow phone, where
        // three money figures on one line would each be ellipsised.
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              for (final (index, tile) in tiles.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.x3),
                SizedBox(width: double.infinity, child: tile),
              ],
            ],
          );
        }

        // `IntrinsicHeight` so the three tiles match even when one figure wraps
        // — `CrossAxisAlignment.stretch` alone needs a bounded height, and this
        // Row lives in a ListView.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, tile) in tiles.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpacing.x3),
                Expanded(child: tile),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RevenueTile extends StatelessWidget {
  const _RevenueTile({
    required this.label,
    required this.pence,
    this.emphasise = false,
  });

  final String label;
  final int pence;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: emphasise ? scheme.primary : context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: emphasise ? null : Border.all(color: context.surfaces.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption(
              emphasise ? scheme.onPrimary : context.surfaces.inkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPence(pence),
              style: AppTypography.money(
                emphasise ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How busy today has been, and what is open right now — two different things,
/// so they are labelled as such.
class _OrdersPanel extends StatelessWidget {
  const _OrdersPanel({required this.orders, this.onTap});

  final OrdersSummary orders;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final open = orders.open;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      orders.today == 1
                          ? '1 order today'
                          : '${orders.today} orders today',
                      style: context.texts.titleMedium,
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: AppIconSize.xl,
                      color: context.surfaces.inkSoft,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                // "Open now" is the live queue, which can include an order
                // placed yesterday — hence the separate wording.
                open.total == 0
                    ? 'Nothing open right now'
                    : '${open.total} open right now',
                style: context.texts.bodySmall?.copyWith(
                  color: context.surfaces.inkSoft,
                ),
              ),
              if (open.total > 0) ...[
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    _QueueChip(label: 'Placed', count: open.placed),
                    _QueueChip(label: 'Preparing', count: open.preparing),
                    _QueueChip(label: 'Ready', count: open.ready),
                    _QueueChip(
                      label: 'Out for delivery',
                      count: open.outForDelivery,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    // A zero stage is muted rather than hidden, so the four stages stay in the
    // same place from one glance to the next.
    final quiet = count == 0;

    return AppChip.status(
      label: '$label $count',
      foreground: quiet ? context.surfaces.inkSoft : colours.preparing,
      background: quiet
          ? context.surfaces.ground
          : colours.preparingContainer,
    );
  }
}

/// A to-do list, not a statistic.
class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.attention,
    this.onBookings,
    this.onMessages,
  });

  final AttentionSummary attention;
  final VoidCallback? onBookings;
  final VoidCallback? onMessages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Needs attention', style: context.texts.titleMedium),
        const SizedBox(height: AppSpacing.x3),
        if (attention.isClear)
          AppSurface.row(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppIconSize.lg,
                  color: context.orderColors.ready,
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    'Nothing waiting. Every request has been answered.',
                    style: context.texts.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (attention.pendingBookings > 0)
            _AttentionRow(
              icon: Icons.event_note_outlined,
              label: attention.pendingBookings == 1
                  ? '1 booking request'
                  : '${attention.pendingBookings} booking requests',
              detail: 'Waiting for approve or reject',
              onTap: onBookings,
            ),
          if (attention.pendingBookings > 0 && attention.newMessages > 0)
            const SizedBox(height: AppSpacing.x3),
          if (attention.newMessages > 0)
            _AttentionRow(
              icon: Icons.mail_outline,
              label: attention.newMessages == 1
                  ? '1 new message'
                  : '${attention.newMessages} new messages',
              detail: 'Sent through the website',
              onTap: onMessages,
            ),
        ],
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.label,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
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
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.surfaces.accentContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: AppIconSize.lg, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.texts.titleSmall),
                    Text(
                      detail,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
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

/// A refresh failed, but the figures below are still worth reading.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: colours.overdueContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: AppIconSize.md,
              color: colours.overdue,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(
              child: Text(
                // Says the numbers are old rather than replacing them with
                // zeros, which would read as a very bad day's trading.
                'Could not refresh. These figures may be out of date.',
                style: context.texts.bodySmall?.copyWith(
                  color: colours.overdue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: AppIconSize.hero,
              color: context.surfaces.inkSoft,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              'Takings are admin only',
              style: context.texts.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              message,
              style: context.texts.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
