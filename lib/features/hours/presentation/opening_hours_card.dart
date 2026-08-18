import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_surface.dart';
import '../domain/working_hours_repository.dart';
import 'working_hours_cubit.dart';

/// The heading and the card together, so both disappear when there is nothing
/// to show. A "Opening Hours" heading standing over an empty box is worse than
/// no section at all.
class OpeningHoursSection extends StatelessWidget {
  const OpeningHoursSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const OpeningHoursCard(withHeading: true);
}

/// The week, for a customer.
///
/// Draws nothing at all until the hours load, and nothing if none are
/// configured — an empty card headed "Opening hours" is worse than no card.
///
/// It deliberately never says "Open now". The backend does not enforce these
/// hours yet, so the app claiming the restaurant is open would be a promise
/// nobody has made. It states the schedule and lets the reader decide.
class OpeningHoursCard extends StatelessWidget {
  const OpeningHoursCard({super.key, this.withHeading = false});

  /// Adds the screen-level heading above the card, and the spacing under it.
  final bool withHeading;

  @override
  Widget build(BuildContext context) {
    final WorkingHoursRepository repository;
    try {
      repository = context.read<WorkingHoursRepository>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => WorkingHoursCubit(repository: repository)..load(),
      child: _HoursCard(withHeading: withHeading),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.withHeading});

  final bool withHeading;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkingHoursCubit, WorkingHoursState>(
      builder: (context, state) {
        // Silent on both loading and failure. This is supporting information on
        // somebody else's screen; a spinner or an error banner for it would be
        // louder than the thing itself.
        if (state.status != HoursStatus.ready || state.saved.isEmpty) {
          return const SizedBox.shrink();
        }

        final today = DateTime.now().weekday - 1;

        final card = AppSurface.row(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: AppIconSize.lg,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Text('Opening hours', style: context.texts.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              for (final day in state.saved.wholeWeek)
                // A day the restaurant has not configured is left out rather
                // than shown as closed — nobody has said either way.
                if (state.saved.isConfigured(day.weekday))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x1 + 1,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            day.name,
                            style: day.weekday == today
                                ? context.texts.titleSmall
                                : context.texts.bodyMedium?.copyWith(
                                    color: context.surfaces.inkMuted,
                                  ),
                          ),
                        ),
                        Text(
                          day.label,
                          style: day.weekday == today
                              ? context.texts.titleSmall
                              : context.texts.bodyMedium?.copyWith(
                                  color: context.surfaces.inkMuted,
                                ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );

        if (!withHeading) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opening Hours', style: context.texts.headlineLarge),
            const SizedBox(height: AppSpacing.x3),
            card,
            const SizedBox(height: AppSpacing.x8),
          ],
        );
      },
    );
  }
}
