import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// Shakes its child whenever [trigger] changes.
///
/// For rejected input. A message alone is easy to miss when it appears below
/// the fold or where the eye isn't looking; a short lateral shudder puts the
/// attention on the control that refused, then gets out of the way.
///
/// Deliberately small and quick — three decaying swings of 8pt over
/// [Motion.slow]. A long or wide shake reads as breakage rather than
/// correction.
///
/// [trigger] is compared, not counted, so pass something that changes on each
/// rejection: an incrementing int, or the error text itself. The same value
/// twice will not re-shake, which is correct — an unchanged complaint is not
/// new information.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger == oldWidget.trigger || widget.trigger == null) return;
    // Reduce-motion drops the shudder entirely: it is pure displacement, and
    // the validation message says the same thing without moving anything.
    if (context.motion.reduced) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ShakeTransition(progress: _controller, child: widget.child);
}

/// Three decaying swings.
///
/// An [AnimatedWidget] rather than an [AnimatedBuilder], so the child is
/// captured once at construction and only the transform re-evaluates per
/// frame.
class _ShakeTransition extends AnimatedWidget {
  const _ShakeTransition({
    required Animation<double> progress,
    required this.child,
  }) : super(listenable: progress);

  static const double _amplitude = 8;
  static const int _swings = 3;

  final Widget child;

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final t = _progress.value;
    if (t == 0 || t == 1) return child;

    // Damped so it settles rather than stopping dead.
    final offset = _amplitude * (1 - t) * math.sin(t * 2 * math.pi * _swings);

    return Transform.translate(offset: Offset(offset, 0), child: child);
  }
}
