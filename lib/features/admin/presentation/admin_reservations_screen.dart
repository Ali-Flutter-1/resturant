import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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
                  state: reservation.state,
                )
                .animate()
                .fadeIn(delay: Motion.staggerFor(index), duration: Motion.quick)
                .slideY(begin: 0.06, end: 0, curve: Motion.enter),
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
              duration: Motion.quick,
              curve: Motion.standard,
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

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.time,
    required this.name,
    required this.party,
    required this.seating,
    required this.note,
    required this.state,
  });

  final String time;
  final String name;
  final int party;
  final String seating;
  final String note;
  final ReservationState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled = state == ReservationState.cancelled;

    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: context.surfaces.restShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 3, color: state.foreground(context)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              time,
                              style: AppTypography.money(
                                scheme.onSurface,
                                size: 18,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: context.surfaces.inkSoft,
                                ),
                                const SizedBox(width: 2),
                                Text('$party', style: context.texts.bodySmall),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.x4),
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
                              const SizedBox(height: 2),
                              Text(seating, style: context.texts.bodySmall),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.x2),
                                _NoteChip(note: note),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        _StateBadge(state: state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Text(note, style: context.texts.labelSmall),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final ReservationState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: state.container(context),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        state.label.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          color: state.foreground(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
