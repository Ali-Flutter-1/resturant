import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Minus / value / plus. Used for party size and basket quantities.
///
/// A pill of two round buttons either side of the figure. The shape is doing the
/// work: the round buttons read as controls and the flat middle reads as a
/// readout, where the old three-rounded-squares-in-a-box looked like three
/// buttons with the middle one broken.
///
/// At the limits the button greys out rather than vanishing, so the control
/// keeps its width and the row it sits in doesn't shift.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.trailingLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// Optional word after the figure, e.g. `Guests`.
  final String? trailingLabel;

  /// Comfortably past the 48pt minimum on the buttons, and the height the
  /// add-to-cart row beside it is built to.
  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        // The neutral ground, not the crimson tint: the tint made a quantity
        // picker as loud as the Add button next to it.
        color: surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: surfaces.line),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            semanticLabel: 'One fewer',
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion.fade(Motion.fast),
              // The new figure rises as the old one drops, so a run of taps
              // reads as counting rather than as the number blinking.
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) =>
                  Stack(
                    alignment: Alignment.center,
                    children: [...previous, ?current],
                  ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: AppTypography.money(
                  Theme.of(context).colorScheme.onSurface,
                  size: MoneySize.medium,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            semanticLabel: 'One more',
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
          if (trailingLabel != null) ...[
            const SizedBox(width: AppSpacing.x3),
            Text(trailingLabel!, style: context.texts.bodyMedium),
            const SizedBox(width: AppSpacing.x2),
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        // The enabled button is the raised surface against the pill's ground,
        // which is what makes it look pressable without a border.
        color: enabled ? context.surfaces.raised : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  AppHaptics.selection();
                  onPressed!();
                }
              : null,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: QuantityStepper.height - 8,
            child: Icon(
              icon,
              size: AppIconSize.xl,
              color: enabled ? scheme.primary : context.surfaces.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
