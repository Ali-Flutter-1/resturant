import 'package:flutter/material.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// The primary call to action.
///
/// Carries the crimson shadow. Presses depress slightly rather than rippling —
/// on a coloured fill a ripple reads as noise.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  /// Set on photographic grounds, where the ambient shadow would be lost.
  final bool onDark;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final motion = context.motion;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled
            ? () {
                AppHaptics.commit();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          // Unity under reduce-motion: the colour shift below still confirms
          // the press, so nothing is lost by holding the button still.
          scale: _pressed ? motion.pressScale : 1,
          duration: motion.move(Motion.instant),
          curve: motion.standard,
          child: AnimatedContainer(
            duration: motion.fade(Motion.instant),
            curve: motion.standard,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x8,
              vertical: AppSpacing.x4,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? (_pressed
                        ? AppColors.crimson700
                        : Theme.of(context).colorScheme.primary)
                  : context.surfaces.lineFirm,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _pressed || !enabled || widget.onDark
                  ? null
                  : context.surfaces.ctaShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: AppIconSize.lg,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: context.texts.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
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

/// The quieter action.
///
/// In the Figma file this was a bare underlined link floating on a photograph.
/// Given a real container it survives on any ground — including the cream
/// screens, where an unstyled white link disappeared entirely.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark
        ? Colors.white.withValues(alpha: 0.92)
        : Theme.of(context).colorScheme.onPrimaryContainer;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(
          color: onDark
              ? Colors.white.withValues(alpha: 0.35)
              : context.surfaces.lineFirm,
        ),
        backgroundColor: onDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: Text(label),
    );
  }
}
