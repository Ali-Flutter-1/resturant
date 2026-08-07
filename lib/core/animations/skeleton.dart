import 'package:flutter/material.dart';

import 'motion.dart';

/// A slow highlight sweeping across whatever it wraps.
///
/// Used to signal "content is coming" on a shape that already matches the
/// content's real layout, so the page doesn't reflow when data lands. A
/// spinner says only that something is happening; a skeleton says what is
/// about to appear and where.
///
/// Under reduce-motion the sweep stops and the surface renders flat — a
/// looping animation is exactly the sort of persistent movement the setting
/// exists to suppress.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Don't burn a ticker on a loop nobody is allowed to see.
    final reduced = context.motion.reduced;
    if (reduced && _controller.isAnimating) {
      _controller.stop();
    } else if (!reduced && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.motion.reduced) return widget.child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        // The child is built once and handed to the builder, keeping the
        // skeleton's own subtree out of the per-frame rebuild path.
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final slide = _controller.value * 2 - 0.5;
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  (slide - 0.3).clamp(0.0, 1.0),
                  slide.clamp(0.0, 1.0),
                  (slide + 0.3).clamp(0.0, 1.0),
                ],
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0),
                ],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}
