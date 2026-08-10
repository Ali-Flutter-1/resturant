import 'package:flutter/material.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/quantity_stepper.dart';

/// Reservation request: party, date, time, where they'd like to sit.
class BookTableScreen extends StatefulWidget {
  const BookTableScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<BookTableScreen> createState() => _BookTableScreenState();
}

class _BookTableScreenState extends State<BookTableScreen> {
  int _partySize = 2;
  DateTime _date = DateTime(2026, 8, 6);
  TimeOfDay? _time;
  int _seating = 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  /// A reservation without a time is not a reservation, so this is the one
  /// field that blocks submission.
  void _confirm() {
    if (_time == null) {
      showAppSnack(
        context,
        'Choose a time for your reservation.',
        isError: true,
      );
      return;
    }
    showAppSnack(
      context,
      'Table for $_partySize booked on $_formattedDate at '
      '${_time!.format(context)}.',
    );
  }

  String get _formattedDate =>
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Tab root: see AboutContactScreen — no dead arrow.
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back',
              ),
        title: const Text('Book a Table'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x5,
          AppSpacing.gutter,
          AppSpacing.x8 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Field(
            label: 'Party Size',
            child: QuantityStepper(
              value: _partySize,
              onChanged: (v) => setState(() => _partySize = v),
              min: 1,
              max: 20,
              trailingLabel: 'Guests',
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          _Field(
            label: 'Date',
            child: _PickerTile(
              icon: Icons.calendar_today_outlined,
              value: _formattedDate,
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          _Field(
            label: 'Time',
            child: _PickerTile(
              icon: Icons.schedule,
              value: _time?.format(context) ?? 'Select a time',
              isPlaceholder: _time == null,
              trailing: Icons.keyboard_arrow_down,
              onTap: _pickTime,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          _Field(
            label: 'Seating Preference (Optional)',
            child: Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                for (final (i, option)
                    in SampleContent.seatingPreferences.indexed)
                  _SeatingChip(
                    label: option,
                    selected: i == _seating,
                    onTap: () => setState(() => _seating = i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          _Field(
            label: 'Special Requests',
            trailing: 'Optional',
            child: TextField(
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Dietary requirements, celebrations, or specific needs...',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),

          FilledButton(
            onPressed: _confirm,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Flexible so a long label or a large text scale
                // shortens the text rather than pushing the arrow
                // out of the button.
                Flexible(
                  child: Text(
                    'Confirm Reservation',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppSpacing.x2),
                Icon(Icons.arrow_forward, size: AppIconSize.md),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Reservations are held for 15 minutes past the booked time. '
            'See our full cancellation policy.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall,
          ),
        ].revealStaggered(),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: context.texts.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.x2),
              Text(trailing!, style: context.texts.bodySmall),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        child,
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.value,
    required this.onTap,
    this.trailing,
    this.isPlaceholder = false,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.lg, color: scheme.primary),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                value,
                style: context.texts.bodyLarge?.copyWith(
                  color: isPlaceholder
                      ? context.surfaces.inkSoft
                      : scheme.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              Icon(
                trailing,
                size: AppIconSize.xl,
                color: context.surfaces.inkSoft,
              ),
          ],
        ),
      ),
    );
  }
}

class _SeatingChip extends StatelessWidget {
  const _SeatingChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colours = context.orderColors;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: context.motion.fade(Motion.fast),
        curve: context.motion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2 + 2,
        ),
        decoration: BoxDecoration(
          // The design highlights the chosen chip in amber, which collides
          // with "preparing" in the admin app. Kept here because it is a
          // customer surface where that meaning never appears.
          color: selected ? colours.preparingContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? colours.preparing.withValues(alpha: 0.5)
                : scheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: context.texts.bodyMedium
              ?.copyWith(color: selected ? colours.preparing : scheme.onSurface)
              .withWeight(selected ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
}
