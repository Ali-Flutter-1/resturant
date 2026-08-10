import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class FlutterGlassNavItem {
  const FlutterGlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The tab bar everywhere iOS's own material isn't available — Android and web.
///
/// iOS gets the real system bar through `CNTabBar`; this is drawn in Flutter, and
/// the point of it is that the two should be hard to tell apart. So it follows
/// UIKit's tab bar rather than Material's `NavigationBar`:
///
///  * **Edge to edge, flush to the bottom.** A floating rounded card is a
///    Material idiom. Apple anchors the bar to the screen edge and lets the
///    home indicator sit inside it.
///  * **A hairline, not a border.** One 0.5px rule along the top edge and
///    nothing else — no outline around the bar, no drop shadow. Depth comes
///    from the translucency, which is how Liquid Glass reads: the bar looks
///    thin because you can see through it.
///  * **Selection is a tint, not a container.** The pill behind the selected
///    icon was the single most Android thing here. UIKit tints the glyph and
///    its label and stops.
///  * **Press dims, it doesn't ripple.** An ink splash out of a circle is
///    unmistakably Material.
///
/// [BackdropFilter] blurs only what Flutter has already painted, which is all
/// that is behind the bar here.
class FlutterGlassNavBar extends StatelessWidget {
  const FlutterGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
  });

  /// UIKit's tab bar content height. The home-indicator inset is added below
  /// this, not carved out of it.
  static const double barHeight = 50;

  /// Breathing room under the labels on a device with no home indicator, so the
  /// bar doesn't sit right on the bezel.
  static const double bottomPaddingWithoutInset = 6;

  final List<FlutterGlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tint ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Translucent enough to read as glass, opaque enough that a label stays
    // legible over a photograph. Apple's own material sits around here; going
    // thinner looks impressive over a plain background and fails over a busy
    // one, which is the failure mode worth avoiding.
    final fill = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.68 : 0.76,
    );

    return ClipRect(
      child: BackdropFilter(
        // Heavier than a card blur. The system material blurs enough that
        // content behind it becomes colour rather than shapes, and a
        // half-blurred photograph reads as a rendering fault.
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: Border(
              // The hairline is the only edge. At 0.5 logical pixels it reads as
              // a change of material rather than as a drawn line.
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.07),
                width: 0.5,
              ),
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
///
/// Stateful only to track the press, which is what gives the bar its iOS feel:
/// the item dims under the finger and comes back, rather than throwing a
/// ripple.
class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final FlutterGlassNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final selected = widget.selected;
    final colour = selected ? widget.accent : context.surfaces.inkSoft;

    return Semantics(
      button: true,
      selected: selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        // No haptic here: the shell plays the selection tick for whichever bar
        // is on screen, and firing one from both places double-taps the motor.
        onTap: () {
          _setPressed(false);
          widget.onTap();
        },
        onTapUp: (_) => _setPressed(false),
        child: AnimatedOpacity(
          // UIKit's touch-down treatment: a quick dim, no geometry change.
          opacity: _pressed ? 0.4 : 1,
          duration: motion.fade(Motion.instant),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // A small overshoot on selection. The whole animation is this
              // scale plus two colour tweens — enough to feel alive, far short
              // of a glyph that bounces every time you change tab.
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: motion.move(Motion.base),
                curve: motion.playful,
                child: AnimatedSwitcher(
                  duration: motion.fade(Motion.fast),
                  // Cross-fades the outline glyph into the filled one, so the
                  // weight change reads as the same icon thickening.
                  child: Icon(
                    selected ? widget.item.selectedIcon : widget.item.icon,
                    key: ValueKey(selected),
                    // 25pt: UIKit's tab bar glyph, which is smaller than
                    // Material's 24 looks once it has a label under it.
                    size: 25,
                    color: colour,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: motion.fade(Motion.fast),
                curve: motion.standard,
                style: AppTypography.navLabel(colour),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
