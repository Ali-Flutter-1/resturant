import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';

/// Gives anything tappable a physical response: it depresses slightly under
/// the finger and settles back, and lifts a little under a pointer.
///
/// Used instead of a ripple on photographic and coloured surfaces, where a
/// Material splash reads as noise. Honours the platform's reduce-motion
/// setting — the callback still fires, the scale simply does not animate.
///
/// The hover lift only ever appears where there is a pointer to hover with:
/// [MouseRegion] reports nothing on a touch screen, so phones get the press
/// response alone and pay nothing for the desktop affordance.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = Motion.pressScale,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far it depresses. Large surfaces want less than small ones.
  final double scale;

  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hovered = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final motion = context.motion;

    // Reduce-motion leaves the target at unity, so the press still registers
    // as a tap but nothing moves. Pressing wins over hovering: on desktop both
    // are true at once, and the press is the more recent intent.
    final double target;
    if (motion.reduced || !enabled) {
      target = 1;
    } else if (_down) {
      target = widget.scale;
    } else if (_hovered) {
      // Half the press depth, in the other direction — enough to say
      // "this responds" without the row jumping as the pointer crosses it.
      target = 1 + (1 - widget.scale) / 2;
    } else {
      target = 1;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enabled ? (_) => _setHovered(true) : null,
      onExit: enabled ? (_) => _setHovered(false) : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: target,
          duration: motion.move(Motion.instant),
          curve: motion.standard,
          child: widget.child,
        ),
      ),
    );
  }
}
