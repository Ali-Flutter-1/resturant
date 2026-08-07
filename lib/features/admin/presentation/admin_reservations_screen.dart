import 'package:flutter/material.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/admin_nav.dart';

enum ReservationState { confirmed, pending, seated, cancelled }

extension on ReservationState {
  String get label => switch (this) {
    ReservationState.confirmed => 'Confirmed',
    ReservationState.pending => 'Pending',
    ReservationState.seated => 'Seated',
    ReservationState.cancelled => 'Cancelled',
  };

  Color foreground(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      ReservationState.confirmed => c.ready,
      ReservationState.pending => c.preparing,
      ReservationState.seated => c.served,
      ReservationState.cancelled => c.overdue,
    };
  }

  Color container(BuildContext context) {
    final c = context.orderColors;
    return switch (this) {
      ReservationState.confirmed => c.readyContainer,
      ReservationState.pending => c.preparingContainer,
      ReservationState.seated => c.servedContainer,
      ReservationState.cancelled => c.overdueContainer,
    };
  }
}

/// Today's covers.
///
/// NOT transcribed from Figma — the MCP quota was exhausted before
/// "Admin Mobile: Reservations (Polished)" (`1:3605`) could be read. Built on
/// the Dashboard's design language; verify against the frame.
class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  int _dayOffset = 0;

  static const _reservations = [
    (
      time: '18:00',
      name: 'Priyanka Fernando',
      party: 2,
      seating: 'Terrace',
      note: 'Anniversary',
      state: ReservationState.confirmed,
    ),
    (
      time: '18:30',
      name: 'James Whitfield',
      party: 4,
      seating: 'Main Dining Room',
      note: '',
      state: ReservationState.confirmed,
    ),
    (
      time: '19:00',
      name: 'Aisha Rahman',
      party: 6,
      seating: 'Main Dining Room',
      note: 'Two high chairs',
      state: ReservationState.pending,
    ),
    (
      time: '19:15',
      name: 'Tom Beresford',
      party: 2,
      seating: 'Any Available',
      note: '',
      state: ReservationState.seated,
    ),
    (
      time: '20:00',
      name: 'Nadia Perera',
      party: 3,
      seating: 'Terrace',
      note: 'Nut allergy',
      state: ReservationState.cancelled,
    ),
  ];

  /// Seating changes made this session. The list is const preview content, so
  /// overrides live beside it rather than mutating it.
  final _seatedOverrides = <String, bool>{};

  ReservationState _stateOf(String name, ReservationState original) {
    final seated = _seatedOverrides[name];
    if (seated == null) return original;
    if (original == ReservationState.cancelled) return original;
    return seated ? ReservationState.seated : ReservationState.confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final covers = _reservations
        .where((r) => r.state != ReservationState.cancelled)
        .fold<int>(0, (sum, r) => sum + r.party);

    return Scaffold(
      appBar: buildAdminAppBar(context),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x2,
          AppSpacing.gutter,
          AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text('Reservations', style: context.texts.headlineLarge),
          const SizedBox(height: AppSpacing.x1),
          Text(
            '$covers covers booked across '
            '${_reservations.length - 1} tables.',
            style: context.texts.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.x5),
          _DayStrip(
            selected: _dayOffset,
            onSelected: (i) => setState(() => _dayOffset = i),
          ),
          const SizedBox(height: AppSpacing.x5),
          for (final (index, reservation) in _reservations.indexed) ...[
            _ReservationCard(
              time: reservation.time,
              name: reservation.name,
              party: reservation.party,
              seating: reservation.seating,
              note: reservation.note,
              state: _stateOf(reservation.name, reservation.state),
              onSeatedChanged: (value) {
                AppHaptics.toggle();
                setState(() => _seatedOverrides[reservation.name] = value);
              },
            ).revealItem(index, duration: Motion.fast),
            if (index != _reservations.length - 1)
              const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _days = [
    (label: 'Today', date: '5 Aug'),
    (label: 'Thu', date: '6 Aug'),
    (label: 'Fri', date: '7 Aug'),
    (label: 'Sat', date: '8 Aug'),
    (label: 'Sun', date: '9 Aug'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      // Tall enough for two lines of type at the largest accessibility text
      // scale most users reach; the Column below stays min-sized so it never
      // fights the box.
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x2),
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          final day = _days[index];

          return GestureDetector(
            onTap: () {
              AppHaptics.selection();
              onSelected(index);
            },
            child: AnimatedContainer(
              duration: context.motion.fade(Motion.fast),
              curve: context.motion.standard,
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? scheme.primary : context.surfaces.line,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.label,
                    style: context.texts.labelSmall?.copyWith(
                      color: isSelected
                          ? scheme.onPrimary
                          : context.surfaces.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    day.date,
                    style: context.texts.titleMedium?.copyWith(
                      color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One booking, laid out as "Reservation Card 1" in the frame: a 4pt heritage
/// accent line down the left edge, the guest's name and where they are sitting
/// on the left, the time and party size on the right, state chips beneath, then
/// a ruled footer carrying a labelled toggle.
///
/// The frame puts the name on the left and the time on the right. This card had
/// them the other way round, which is the kind of thing only the design can
/// settle.
class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.time,
    required this.name,
    required this.party,
    required this.seating,
    required this.note,
    required this.state,
    this.onSeatedChanged,
  });

  final String time;
  final String name;
  final int party;
  final String seating;
  final String note;
  final ReservationState state;

  /// The frame's toggle. What it switches is not recoverable from metadata;
  /// seating the party is the only per-booking state this screen owns.
  final ValueChanged<bool>? onSeatedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled = state == ReservationState.cancelled;
    final seated = state == ReservationState.seated;

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: AppSurface.row(
        padding: EdgeInsets.zero,
        // Clipped because the accent line paints to the card's edge.
        clip: true,
        child: Stack(
          children: [
            // Heritage accent line. Positioned rather than a stretched Row
            // child so the card's height stays driven by its content.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: state.foreground(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4 + 4,
                AppSpacing.x4,
                AppSpacing.x4,
                0,
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
                            Text(
                              name,
                              style: context.texts.titleMedium?.copyWith(
                                decoration: cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.x1),
                            Row(
                              children: [
                                Icon(
                                  Icons.chair_outlined,
                                  size: AppIconSize.xs,
                                  color: context.surfaces.inkSoft,
                                ),
                                const SizedBox(width: AppSpacing.x1),
                                Expanded(
                                  child: Text(
                                    seating,
                                    style: context.texts.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            time,
                            style: AppTypography.money(
                              scheme.onSurface,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.x1),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: AppIconSize.xs,
                                color: context.surfaces.inkSoft,
                              ),
                              const SizedBox(width: AppSpacing.x1),
                              Text('$party', style: context.texts.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  // Two chips in the frame: the booking's state, and any
                  // note against it.
                  Row(
                    children: [
                      AppChip.status(
                        label: state.label,
                        foreground: state.foreground(context),
                        background: state.container(context),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.x2),
                        Flexible(child: AppChip.outlined(label: note)),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Divider(height: 1, color: context.surfaces.line),
                  SizedBox(
                    height: 41,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            seated ? 'Seated' : 'Not seated',
                            style: context.texts.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Switch(
                          value: seated,
                          onChanged: cancelled ? null : onSeatedChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
