import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/reveal.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/api_error_view.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/session_refresh.dart';
import '../domain/reservation.dart';
import '../domain/reservation_repository.dart';
import 'my_bookings_cubit.dart';

/// The customer's table bookings.
class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key, this.onBack, this.onBookTable});

  final VoidCallback? onBack;

  /// Offered from the empty state.
  final VoidCallback? onBookTable;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          MyBookingsCubit(repository: context.read<ReservationRepository>())
            ..load(),
      child: _MyBookingsView(onBack: onBack, onBookTable: onBookTable),
    );
  }
}

class _MyBookingsView extends StatelessWidget {
  const _MyBookingsView({this.onBack, this.onBookTable});

  final VoidCallback? onBack;
  final VoidCallback? onBookTable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
      ),
      body: BlocBuilder<MyBookingsCubit, MyBookingsState>(
        builder: (context, state) {
          final cubit = context.read<MyBookingsCubit>();

          if (state.status == BookingsStatus.loading) {
            return const MessageListSkeleton();
          }
          if (state.status == BookingsStatus.failure && state.failure != null) {
            return ApiErrorView(
              failure: state.failure!,
              onRetry: () => cubit.load(),
            );
          }
          if (state.bookings.isEmpty) {
            return _NoBookings(onBookTable: onBookTable);
          }

          final live = state.live;
          final past = state.past;

          return RefreshIndicator(
            onRefresh: () =>
                refreshWithSession(context, () => cubit.load(silent: true)),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x4,
                AppSpacing.gutter,
                AppSpacing.x12 + MediaQuery.paddingOf(context).bottom,
              ),
              children:
                  [
                    if (live.isNotEmpty) ...[
                      _Heading(
                        live.length == 1 ? 'Your booking' : 'Your bookings',
                      ),
                      for (final booking in live)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.x3,
                          ),
                          child: _BookingRow(booking: booking),
                        ),
                    ],
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x3),
                      const _Heading('Earlier'),
                      for (final booking in past)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.x3,
                          ),
                          child: _BookingRow(booking: booking),
                        ),
                    ],
                    if (state.hasMore)
                      Center(
                        child: state.loadingMore
                            ? const Padding(
                                padding: EdgeInsets.all(AppSpacing.x3),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : OutlinedButton(
                                onPressed: cubit.loadMore,
                                child: const Text('Load more'),
                              ),
                      ),
                  ].revealStaggered(),
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(title, style: context.texts.titleMedium),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});

  final ReservationSummary booking;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => showBookingDetail(context, booking.id),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.tableName, style: context.texts.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${_dayLabel(booking.serviceDate)} at '
                      '${booking.timeLabel} · ${booking.guestLabel}',
                      style: context.texts.bodySmall?.copyWith(
                        color: context.surfaces.inkSoft,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    _StatusChip(status: booking.status),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    booking.reference,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.surfaces.inkSoft,
                    ),
                  ),
                  if (booking.pricePence > 0)
                    Text(
                      formatBookingPrice(booking.pricePence),
                      style: context.texts.bodyMedium,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    final (foreground, background) = switch (status) {
      ReservationStatus.pending => (
        colours.preparing,
        colours.preparingContainer,
      ),
      ReservationStatus.confirmed ||
      ReservationStatus.seated => (colours.ready, colours.readyContainer),
      ReservationStatus.completed => (colours.served, colours.servedContainer),
      ReservationStatus.rejected ||
      ReservationStatus.cancelled ||
      ReservationStatus.noShow ||
      ReservationStatus.expired => (colours.overdue, colours.overdueContainer),
    };

    return AppChip.status(
      label: status.label,
      foreground: foreground,
      background: background,
    );
  }
}

/// One booking, watched while it is pending.
void showBookingDetail(BuildContext context, String id) {
  final cubit = context.read<MyBookingsCubit>();
  cubit.open(id);
  showAppSheet<void>(
    context: context,
    title: 'Booking',
    child: BlocProvider.value(value: cubit, child: const _BookingDetail()),
    // Watching stops with the screen: a timer that outlives the sheet is a
    // request every ten seconds for something nobody is looking at.
  ).whenComplete(cubit.stopWatching);
}

class _BookingDetail extends StatefulWidget {
  const _BookingDetail();

  @override
  State<_BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends State<_BookingDetail> {
  AppLifecycleListener? _lifecycle;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Backgrounding stops the polling; coming back reads once and restarts it,
    // but only if the booking is still pending.
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<MyBookingsCubit>().resumeWatching(),
      onPause: () => context.read<MyBookingsCubit>().stopWatching(),
    );
    // Redraws the countdown. Separate from the polling, and only a display
    // concern — the server decides when a request has actually expired.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _cancel(BuildContext context, ReservationDetail booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel booking ${booking.reference}?'),
        content: const Text(
          'The table is released straight away and cannot be reclaimed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.orderColors.overdue,
            ),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await context.read<MyBookingsCubit>().cancel(booking.id);
    if (!context.mounted) return;
    if (error != null) {
      AppHaptics.failure();
      // The API's own words. RESERVATION_ALREADY_APPROVED says exactly what
      // happened and what to do about it.
      showAppSnack(context, error, isError: true);
      return;
    }
    AppHaptics.success();
    showAppSnack(context, 'Booking cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyBookingsCubit, MyBookingsState>(
      builder: (context, state) {
        final booking = state.detail;
        if (booking == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.x8),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: booking.status),
                  const SizedBox(width: AppSpacing.x2),
                  Text(
                    booking.reference,
                    style: context.texts.labelSmall?.copyWith(
                      color: context.surfaces.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(booking.status.customerNote, style: context.texts.bodyMedium),

              if (booking.status == ReservationStatus.pending &&
                  booking.timeLeft != null) ...[
                const SizedBox(height: AppSpacing.x3),
                _Countdown(left: booking.timeLeft!),
              ],

              if (booking.cancellationReason != null) ...[
                const SizedBox(height: AppSpacing.x3),
                _Reason(booking: booking),
              ],

              const SizedBox(height: AppSpacing.x5),
              _Detail(label: 'Table', value: booking.tableName),
              _Detail(
                label: 'When',
                value:
                    '${_dayLabel(booking.serviceDate)} at ${booking.timeLabel}',
              ),
              _Detail(label: 'Party', value: booking.guestLabel),
              if (booking.pricePence > 0)
                _Detail(
                  label: 'Table price',
                  value: formatBookingPrice(booking.pricePence),
                ),
              _Detail(label: 'Name', value: booking.contactName),
              _Detail(label: 'Phone', value: booking.contactPhone),
              if (booking.specialRequests != null)
                _Detail(label: 'Requests', value: booking.specialRequests!),

              const SizedBox(height: AppSpacing.x5),
              // Only ever the server's answer. Deriving it from the status would
              // put the button back on a booking staff approved a second ago.
              if (booking.canCancel)
                OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => _cancel(context, booking),
                  icon: state.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.close, size: AppIconSize.md),
                  label: Text(
                    state.busy ? 'Cancelling…' : 'Cancel this booking',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: context.orderColors.overdue,
                  ),
                )
              else if (booking.status == ReservationStatus.confirmed)
                Text(
                  'To change or cancel a confirmed booking, please contact the '
                  'restaurant.',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// How long the restaurant has left to answer.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: colours.preparingContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_bottom,
            size: AppIconSize.md,
            color: colours.preparing,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              'About ${minutes.toString().padLeft(2, '0')}:'
              '${seconds.toString().padLeft(2, '0')} left for the restaurant '
              'to answer.',
              style: context.texts.bodySmall?.copyWith(
                color: colours.preparing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.booking});

  final ReservationDetail booking;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: colours.overdueContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The restaurant said',
            style: context.texts.titleSmall?.copyWith(color: colours.overdue),
          ),
          const SizedBox(height: 2),
          Text(booking.cancellationReason!, style: context.texts.bodyMedium),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: context.surfaces.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: Text(value, style: context.texts.bodyMedium)),
        ],
      ),
    );
  }
}

class _NoBookings extends StatelessWidget {
  const _NoBookings({this.onBookTable});

  final VoidCallback? onBookTable;

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
                  Icons.event_seat_outlined,
                  size: AppIconSize.hero,
                  color: context.surfaces.inkSoft,
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  'No bookings yet',
                  style: context.texts.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Reserve a table and it will appear here.',
                  style: context.texts.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (onBookTable != null) ...[
                  const SizedBox(height: AppSpacing.x5),
                  FilledButton(
                    onPressed: onBookTable,
                    child: const Text('Book a table'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final difference = DateTime(date.year, date.month, date.day)
      .difference(today)
      .inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference == -1) return 'Yesterday';

  const months = [
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
  return '${date.day} ${months[date.month - 1]}';
}
