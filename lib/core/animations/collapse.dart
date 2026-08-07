import 'package:flutter/material.dart';

import 'motion.dart';

/// Folds its child away, then reports that it has finished.
///
/// For removing something from a list. Deleting a row by simply dropping it
/// from the build makes everything below it jump up by the row's height, and
/// the jump is the only thing the eye registers — you see movement without
/// seeing *what* left. Folding the row shut shows the gap closing, so the
/// removal explains itself and the rows below arrive where you expect.
///
/// Give it [collapsed] and it animates shut; [onCollapsed] fires once the row
/// has no height left, which is when the caller should actually drop the item
/// from its state. Setting [collapsed] back to false mid-fold reopens it,
/// which is what makes an undo feel like a reversal rather than a re-insert.
class Collapse extends StatefulWidget {
  const Collapse({
    super.key,
    required this.collapsed,
    required this.child,
    this.onCollapsed,
  });

  final bool collapsed;
  final Widget child;

  /// Called once the fold completes. Not called if [collapsed] goes back to
  /// false first — a reversed fold never finished.
  final VoidCallback? onCollapsed;

  @override
  State<Collapse> createState() => _CollapseState();
}

class _CollapseState extends State<Collapse>
    with SingleTickerProviderStateMixin {
  // 1 is open, 0 is folded shut.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: widget.collapsed ? 0 : 1,
  );

  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: Motion.standard,
  );

  /// The content leaves before the space does. Fading over the first half of
  /// the fold means the gap closes on an already-empty row, rather than
  /// crushing legible content as it shrinks.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.onCollapsed?.call();
  }

  @override
  void didUpdateWidget(Collapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed == oldWidget.collapsed) return;

    if (context.motion.reduced) {
      // No fold, but the caller still needs telling, and it must not happen
      // during this build.
      _controller.value = widget.collapsed ? 0 : 1;
      if (widget.collapsed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onCollapsed?.call();
        });
      }
      return;
    }

    widget.collapsed ? _controller.reverse() : _controller.forward();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}
