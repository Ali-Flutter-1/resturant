import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;

  /// Outlined glyph, for an inactive item.
  final IconData icon;

  /// Filled glyph, for the active one.
  final IconData selectedIcon;
}

/// The tab bar everywhere iOS's own material isn't available — Android and web.
///
/// Modelled on Material 3's `NavigationBar` rather than reusing it, because the
/// shell needs the bar to be a plain widget it can slide off-screen and to
/// report its own height. The M3 metrics are followed literally:
///
///  * **64pt of content, plus the system inset.** M3 specifies an 80pt bar; that
///    is 64 of content and 16 of bottom padding, which on Android is the gesture
///    inset. So the inset is added below the content rather than baked in, and a
///    device without one gets [bottomPaddingWithoutInset] instead.
///  * **A 64×32 active indicator.** The pill is the M3 selected-state signal.
///    Tinted with the app's own `accentContainer` rather than
///    `secondaryContainer`, so selection reads as the brand crimson.
///  * **24pt glyphs, outlined → filled, with a 4pt gap to the label.** One icon
///    size and one label style across every tab; the fill and the tint change
///    together so the active item reads at a glance.
///  * **Edge to edge, flush to the bottom.** M3 anchors the bar to the screen
///    edge — a floating rounded card is an M2 idiom.
///
/// [BackdropFilter] is kept from the previous design: the shell sets
/// `extendBody`, so content scrolls behind the bar, and a light blur under a
/// near-opaque surface keeps that from looking like a clipping fault.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
  });

  /// M3's content height. The system inset is added below this, not carved out
  /// of it — see the class note.
  static const double barHeight = 64;

  /// M3's 16pt bottom padding, for a device with no gesture inset of its own.
  static const double bottomPaddingWithoutInset = 16;

  /// The active indicator, at M3's dimensions.
  static const double _indicatorWidth = 64;
  static const double _indicatorHeight = 32;

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Selected-item colour. Defaults to the theme's primary.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = context.surfaces;
    final accent = tint ?? theme.colorScheme.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // M3's bar is an opaque `surfaceContainer`. Held just short of opaque so the
    // blur still has something to do where content passes behind, which is the
    // one thing an edge-to-edge bar over a scrolling list needs.
    final fill = surfaces.raised.withValues(alpha: 0.94);

    return ClipRect(
      child: BackdropFilter(
        // Lighter than the old glass blur: the surface above it is nearly
        // opaque, so this only has to soften what shows through at the edges.
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              // A hairline instead of M3's elevation. An edge-to-edge bar with a
              // drop shadow reads as a card that happens to touch the bottom.
              top: BorderSide(color: surfaces.line, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset > 0 ? bottomInset : bottomPaddingWithoutInset,
            ),
            child: SizedBox(
              height: barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, item) in items.indexed)
                    Expanded(
                      child: _NavButton(
                        item: item,
                        selected: index == currentIndex,
                        accent: accent,
                        onTap: () => onTap(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final surfaces = context.surfaces;
    final colour = selected ? accent : surfaces.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          // No haptic here: the shell plays the selection tick for whichever bar
          // is on screen, and firing one from both places double-taps the motor.
          onTap: onTap,
          // The whole cell is the target — 64pt tall by a fifth of the screen,
          // comfortably past the 48pt minimum — but the ripple is a rounded rect
          // inside it, so it never runs into the bar's edges or its neighbour.
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          splashColor: accent.withValues(alpha: 0.10),
          highlightColor: accent.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: AppNavBar._indicatorWidth,
                height: AppNavBar._indicatorHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // M3's active indicator. Scaled in from the centre rather
                    // than faded, so selection travels with the tap instead of
                    // two pills briefly overlapping.
                    AnimatedScale(
                      scale: selected ? 1 : 0.6,
                      duration: motion.move(Motion.base),
                      curve: motion.emphasized,
                      child: AnimatedOpacity(
                        opacity: selected ? 1 : 0,
                        duration: motion.fade(Motion.fast),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: surfaces.accentContainer,
                            borderRadius: BorderRadius.circular(
                              AppNavBar._indicatorHeight / 2,
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: motion.fade(Motion.fast),
                      // Cross-fades the outline glyph into the filled one, so
                      // the weight change reads as the same icon thickening.
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        key: ValueKey(selected),
                        // M3's tab glyph, and the app's `xxl` step less four —
                        // 24 is the one size every bar icon uses.
                        size: 24,
                        color: colour,
                      ),
                    ),
                  ],
                ),
              ),
              // M3's icon-to-label gap.
              const SizedBox(height: AppSpacing.x1),
              // Clamped, because the bar's height is fixed: past about 1.2 the
              // label starts eating into the indicator rather than wrapping.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: AnimatedDefaultTextStyle(
                  duration: motion.fade(Motion.fast),
                  curve: motion.standard,
                  style: AppTypography.navLabel(
                    colour,
                  ).copyWith(fontWeight: selected ? FontWeight.w600 : null),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
