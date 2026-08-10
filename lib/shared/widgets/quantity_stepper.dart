import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Minus / value / plus. Used for party size and basket quantities.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x2),
      decoration: BoxDecoration(
        color: context.surfaces.accentContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion.fade(Motion.fast),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: AppTypography.money(
                  scheme.onSurface,
                  size: MoneySize.medium,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
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
  const _StepButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed == null
            ? null
            : () {
                AppHaptics.selection();
                onPressed!();
              },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: AppIconSize.lg,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : context.surfaces.inkSoft,
          ),
        ),
      ),
    );
  }
}
