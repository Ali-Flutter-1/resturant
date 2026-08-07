import 'package:flutter/material.dart';

import 'motion.dart';

/// A number that counts to its value rather than appearing at it.
///
/// Used for figures the eye is meant to register as quantities — takings,
/// covers, order counts. The point is not decoration: watching a number climb
/// tells you its scale before you have read a single digit, and it marks the
/// figure as *live* rather than a label that happens to contain numerals.
///
/// Built on [TweenAnimationBuilder], so changing [value] later animates from
/// wherever the display currently is. No controller, nothing to dispose.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.slow,
  });

  final double value;

  /// How the running value becomes text. Keep the digit count fixed across the
  /// range — a figure that changes width mid-count drags the layout with it.
  final String Function(double value) format;

  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;

    // Reduce-motion shows the figure outright. A counting number is movement,
    // and it is movement the user cannot opt out of by looking away.
    if (motion.reduced) {
      return Text(format(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Motion.enter,
      builder: (context, running, _) => Text(format(running), style: style),
    );
  }
}
