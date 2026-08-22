import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// The app's chip: a short label on a rounded ground.
///
/// This replaces eight near-identical implementations that had drifted apart —
/// `10/4` padding against `8/3`, pill radius against `sm`, uppercase against
/// sentence case, `w600` against the inherited weight. None of those
/// differences meant anything; together they were why rows of chips never
/// quite lined up.
///
/// One set of metrics for all of them, so a chip is the same object wherever it
/// appears:
///
///  * `x3` horizontal and `x1` vertical padding
///  * pill radius
///  * `labelSmall`, and [emphasise] for the upper-case treatment status wants
///
/// Colour is the only thing a caller varies, because colour is the only thing
/// that carries meaning here.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.foreground,
    this.background,
    this.icon,
    this.showDot = false,
    this.outlined = false,
    this.emphasise = false,
  });

  /// A status chip: coloured ground, upper-case label, and a dot for
  /// peripheral vision.
  const AppChip.status({
    super.key,
    required this.label,
    required Color this.foreground,
    required Color this.background,
    this.showDot = true,
  }) : icon = null,
       outlined = false,
       emphasise = true;

  /// A quiet chip that states a fact without competing: no fill, just a hairline.
  const AppChip.outlined({super.key, required this.label, this.icon})
    : foreground = null,
      background = null,
      showDot = false,
      outlined = true,
      emphasise = false;

  final String label;

  /// Defaults to the muted ink, which is what a chip carrying no state wants.
  final Color? foreground;

  /// Defaults to the page's own ground, so an unstyled chip recedes.
  final Color? background;

  /// A leading glyph, sized to sit on the label's line.
  final IconData? icon;

  /// A 6pt dot ahead of the label. Cheaper to read at a glance than the word.
  final bool showDot;

  final bool outlined;

  /// Upper-cases the label and weights it. For state, never for content — a
  /// dish tag shouted in capitals reads as an alarm.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? context.surfaces.inkMuted;
    final bg = outlined
        ? Colors.transparent
        : (background ?? context.surfaces.ground);
    final labelStyle = context.texts.labelSmall?.copyWith(color: fg);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: outlined ? Border.all(color: context.surfaces.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.x2),
          ] else if (icon != null) ...[
            Icon(icon, size: AppIconSize.xs, color: fg),
            const SizedBox(width: AppSpacing.x1),
          ],
          // Flexible so a chip in a narrow row shortens its label rather than
          // pushing itself past the edge of its parent.
          Flexible(
            child: Text(
              emphasise ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: emphasise
                  ? labelStyle?.withWeight(FontWeight.w700)
                  : labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip the user chooses: filter strips, category strips, tag pickers.
///
/// These were four separate implementations that differed only in vertical
/// padding, and each re-declared its own haptic and its own transition. Both
/// now live here, so selecting a filter feels identical to selecting a tag —
/// which is the point of an interaction pattern.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.onManage,
    this.manageIcon = Icons.more_horiz,
    this.manageTooltip,
  });

  final String label;
  final bool selected;

  /// Null disables the chip — for a form mid-submit, where changing the
  /// selection would race the request already carrying the old one.
  final VoidCallback? onSelected;

  /// A second action on the chip, shown as a glyph after the label.
  ///
  /// Only for something the chip *is* rather than something it filters: on a
  /// category chip this edits the category itself. Left null the chip is
  /// exactly as it was, with no glyph and no second target.
  final VoidCallback? onManage;

  final IconData manageIcon;
  final String? manageTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;

    final onSelected = this.onSelected;

    return GestureDetector(
      onTap: onSelected == null
          ? null
          : () {
              AppHaptics.selection();
              onSelected();
            },
      child: AnimatedContainer(
        // A colour change only, so it stays a fade under reduce-motion.
        duration: motion.fade(Motion.fast),
        curve: motion.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? scheme.primary : context.surfaces.line,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
            if (onManage != null) ...[
              const SizedBox(width: AppSpacing.x2),
              // Its own target, so tapping the glyph edits and tapping the
              // label still selects. A hidden long-press was the only way in
              // before, which meant nobody found it.
              Semantics(
                button: true,
                label: manageTooltip ?? 'Edit $label',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.toggle();
                    onManage!();
                  },
                  child: Padding(
                    // Widens the glyph's target without making the chip taller
                    // -- 24pt of icon plus this reaches a comfortable thumb
                    // size inside a chip that has to stay chip-sized.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x1,
                      vertical: AppSpacing.x2,
                    ),
                    child: Icon(
                      manageIcon,
                      size: AppIconSize.md,
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.8)
                          : context.surfaces.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
