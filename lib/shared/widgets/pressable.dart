import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';

/// Gives anything tappable a physical response: it depresses slightly under
/// the finger and settles back.
///
/// Used instead of a ripple on photographic and coloured surfaces, where a
/// Material splash reads as noise. Honours the platform's reduce-motion
/// setting — the callback still fires, the scale simply does not animate.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
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

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final target = (_down && enabled && !reduceMotion) ? widget.scale : 1.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: target,
        duration: Motion.instant,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}
