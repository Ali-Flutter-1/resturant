import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/skeleton.dart';
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
            // Shaped like the dashboard, not like a message list: a placeholder
            // whose layout matches what arrives makes the wait read as this
            // screen loading rather than as a different screen being replaced.
            return const _DashboardSkeleton();
          }

          // A staff account, or an admin demoted mid-session. Not a retry —
          // signing in again produces the same role and the same refusal.
          if (state.isForbidden && state.summary == null) {
            return _NoAccess(message: state.failure!.message);
          }

          if (state.status == DashboardStatus.failure &&
              state.failure != null) {
            return ApiErrorView(failure: state.failure!, onRetry: cubit.load);
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
              children: [
                // Figures stay put through a failed refresh — zero revenue
                // is a real number and must never stand in for "failed".
                if (state.isStale) _StaleBanner(state: state),
                const _SectionHeading('Takings'),
                _RevenueBlock(revenue: summary.revenue),
                const SizedBox(height: AppSpacing.x6),
                const _SectionHeading('Service'),
                _OrdersPanel(orders: summary.orders, onTap: widget.onViewAll),
                const SizedBox(height: AppSpacing.x6),
                const _SectionHeading('Needs attention'),
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

/// Stands in for the real thing while the one request is in flight.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: pagePadding(context, top: AppSpacing.x4),
        children: [
          Skeleton.line(width: 70, height: 10),
          const SizedBox(height: AppSpacing.x3),
          // The hero card.
          Skeleton.box(
            width: double.infinity,
            height: 104,
            radius: AppRadius.lg,
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Expanded(child: Skeleton.box(height: 78, radius: AppRadius.md)),
              const SizedBox(width: AppSpacing.x3),
              Expanded(child: Skeleton.box(height: 78, radius: AppRadius.md)),
            ],
          ),
          const SizedBox(height: AppSpacing.x6),
          Skeleton.line(width: 60, height: 10),
          const SizedBox(height: AppSpacing.x3),
          Skeleton.box(
            width: double.infinity,
            height: 122,
            radius: AppRadius.md,
          ),
          const SizedBox(height: AppSpacing.x6),
          Skeleton.line(width: 110, height: 10),
          const SizedBox(height: AppSpacing.x3),
          Skeleton.box(
            width: double.infinity,
            height: 74,
            radius: AppRadius.md,
          ),
        ],
      ),
    );
  }
}

/// Takings.
///
/// Today is the figure anybody opening this screen came for, so it gets the
/// card. Week and month support it underneath at half the weight — deliberately
/// not framed as a comparison, because a month can start mid-week and
/// `today <= week <= month` is not guaranteed.
class _RevenueBlock extends StatelessWidget {
  const _RevenueBlock({required this.revenue});

  final RevenueTiles revenue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TodayCard(pence: revenue.todayPence),
        const SizedBox(height: AppSpacing.x3),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _RevenueTile(label: 'This week', pence: revenue.thisWeekPence),
              _RevenueTile(label: 'This month', pence: revenue.thisMonthPence),
            ];

            // Stacked on a narrow phone, where two money figures on one line
            // would each be ellipsised.
            if (constraints.maxWidth < 300) {
              return Column(
                children: [
                  tiles.first,
                  const SizedBox(height: AppSpacing.x3),
                  tiles.last,
                ],
              );
            }

            // `IntrinsicHeight` so both tiles match even when one figure wraps
            // — `stretch` alone needs a bounded height, and this Row lives in
            // a ListView.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles.first),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(child: tiles.last),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The headline figure.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.pence});

  final int pence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        // A two-stop wash rather than a flat fill, so the card reads as the
        // one thing on the screen with weight behind it.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.22)!,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAKEN TODAY',
                  style: AppTypography.caption(
                    scheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPence(pence),
                    // Not tabular: a single headline figure set in full-width
                    // commas reads as "£1 , 240 . 00".
                    style: AppTypography.money(
                      scheme.onPrimary,
                      size: MoneySize.hero,
                      tabular: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          // Decorative, and marked as such — a screen reader announcing
          // "graph" here would add nothing to the figure beside it.
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up,
                size: AppIconSize.lg,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTile extends StatelessWidget {
  const _RevenueTile({required this.label, required this.pence});

  final String label;
  final int pence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.surfaces.raised,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.caption(context.surfaces.inkSoft),
          ),
          const SizedBox(height: AppSpacing.x1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPence(pence),
              style: AppTypography.money(
                scheme.onSurface,
                size: MoneySize.large,
                tabular: false,
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
    final colours = context.orderColors;
    final stages = [
      _Stage(
        'Placed',
        open.placed,
        colours.preparing,
        colours.preparingContainer,
      ),
      _Stage(
        'Preparing',
        open.preparing,
        colours.overdue,
        colours.overdueContainer,
      ),
      _Stage('Ready', open.ready, colours.ready, colours.readyContainer),
      _Stage(
        'Delivering',
        open.outForDelivery,
        colours.served,
        colours.servedContainer,
      ),
    ];

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
                const SizedBox(height: AppSpacing.x4),
                _QueueBar(stages: stages, total: open.total),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final stage in stages) _QueueChip(stage: stage),
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

/// One stage of the live queue.
class _Stage {
  const _Stage(this.label, this.count, this.ink, this.container);

  final String label;
  final int count;
  final Color ink;
  final Color container;
}

/// The open queue as one bar, split by how much of it each stage holds.
///
/// The shape carries the reading before any number is parsed: mostly amber
/// means the kitchen is behind, mostly green means the counter is.
class _QueueBar extends StatelessWidget {
  const _QueueBar({required this.stages, required this.total});

  final List<_Stage> stages;
  final int total;

  @override
  Widget build(BuildContext context) {
    // The counts beside it say the same thing more precisely, so the bar is
    // decoration as far as a screen reader is concerned.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              for (final stage in stages)
                if (stage.count > 0)
                  Expanded(
                    // Integer flex, so a one-order stage still shows: the
                    // segments are weighted by count and never rounded to zero.
                    flex: stage.count,
                    child: AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.standard,
                      color: stage.ink,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({required this.stage});

  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    // A zero stage is muted rather than hidden, so the four stages stay in the
    // same place from one glance to the next.
    final quiet = stage.count == 0;

    return AppChip.status(
      label: '${stage.label} ${stage.count}',
      foreground: quiet ? context.surfaces.inkSoft : stage.ink,
      background: quiet ? context.surfaces.ground : stage.container,
    );
  }
}

/// A quiet label over each block, so the screen reads as three sections rather
/// than one run of cards.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption(context.surfaces.inkSoft),
      ),
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
