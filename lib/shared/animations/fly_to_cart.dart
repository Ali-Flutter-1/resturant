import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';

/// Flies a copy of a widget along a curved path into the cart.
///
/// The copy is painted in the root [Overlay], above every route, so it is
/// never clipped by the scroll view it started in and never disturbs the
/// layout it left behind. The original stays exactly where it is.
///
/// Everything animates from a single [AnimationController] driving
/// [Transform] and [Opacity] — no layout or paint work per frame beyond
/// compositing one small subtree, which is what keeps it at 60fps. The
/// overlay is wrapped in [IgnorePointer], so the user can keep tapping while
/// it flies.
abstract final class FlyToCart {
  /// Launches the flight. Returns once the copy has landed and been removed.
  ///
  /// [onArrive] fires the instant the copy reaches the cart — bump the badge
  /// there, so the count changes exactly as the item lands rather than
  /// before it sets off.
  static Future<void> launch({
    required BuildContext context,
    required GlobalKey sourceKey,
    required GlobalKey targetKey,
    required Widget child,
    Duration duration = Motion.slow,
    double endScale = 0.16,
    VoidCallback? onArrive,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final sourceBox =
        sourceKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;

    // If anything is missing — or the user has asked for reduced motion —
    // skip straight to the outcome. The feedback still happens; only the
    // flourish is dropped.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (overlay == null ||
        sourceBox == null ||
        targetBox == null ||
        !sourceBox.hasSize ||
        !targetBox.hasSize ||
        reduceMotion) {
      onArrive?.call();
      return;
    }

    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) {
      onArrive?.call();
      return;
    }

    // Measured at launch, in overlay space, so a rotation or resize mid-flight
    // cannot leave the copy chasing a stale target.
    final size = sourceBox.size;
    final start = sourceBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final end = targetBox
        .localToGlobal(targetBox.size.center(Offset.zero), ancestor: overlayBox)
        // The copy is positioned by its top-left, so offset by half its
        // final, scaled size to land centred on the icon.
        .translate(-size.width * endScale / 2, -size.height * endScale / 2);

    final completer = Completer<void>();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _Flight(
        start: start,
        end: end,
        size: size,
        endScale: endScale,
        duration: duration,
        onArrive: onArrive,
        onDone: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
        child: child,
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }
}

class _Flight extends StatefulWidget {
  const _Flight({
    required this.start,
    required this.end,
    required this.size,
    required this.endScale,
    required this.duration,
    required this.onDone,
    required this.child,
    this.onArrive,
  });

  final Offset start;
  final Offset end;
  final Size size;
  final double endScale;
  final Duration duration;
  final VoidCallback onDone;
  final VoidCallback? onArrive;
  final Widget child;

  @override
  State<_Flight> createState() => _FlightState();
}

class _FlightState extends State<_Flight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  bool _arrived = false;

  /// Where the curve bows. Lifted above the straight line and pulled toward
  /// the target, which reads as an arc thrown toward the cart rather than a
  /// diagonal slide.
  late final Offset _control = () {
    final delta = widget.end - widget.start;
    final lift = math.max(90.0, delta.distance * 0.32);
    return Offset(
      widget.start.dx + delta.dx * 0.72,
      math.min(widget.start.dy, widget.end.dy) - lift,
    );
  }();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.addListener(() {
      // Fire on arrival, not on removal, so the badge ticks over at the
      // moment the item visually lands.
      if (!_arrived && _controller.value >= 0.92) {
        _arrived = true;
        widget.onArrive?.call();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Re-normalises [value] within the sub-range [start]–[end] to 0–1.
  ///
  /// The clamp is not decoration. `(1.0 - 0.7) / 0.3` evaluates to
  /// 1.0000000000000002 in IEEE-754, and [Curve.transform] asserts its input
  /// is within 0–1 — so the final frame of a phase can crash on a rounding
  /// error alone.
  static double _phase(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);

  Offset _pointAt(double t) {
    final u = 1 - t;
    return widget.start * (u * u) +
        _control * (2 * u * t) +
        widget.end * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = _controller.value;

        // Position eases in and out; the arc does the rest of the work.
        final travel = Motion.standard.transform(raw);
        final position = _pointAt(travel);

        // A touch of anticipation — it swells before it leaves — then
        // shrinks away steadily.
        final scale = raw < 0.16
            ? 1 + Curves.easeOut.transform(_phase(raw, 0, 0.16)) * 0.06
            : 1.06 -
                  (1.06 - widget.endScale) *
                      Motion.exit.transform(_phase(raw, 0.16, 1));

        // Holds full strength most of the way, then fades as it lands, so
        // it disappears *into* the cart rather than vanishing early.
        final opacity = raw < 0.7
            ? 1.0
            : 1.0 - Curves.easeIn.transform(_phase(raw, 0.7, 1)) * 0.65;

        // Barely perceptible tumble; enough to feel physical.
        final angle = Curves.easeInOut.transform(raw) * 0.28;

        // Positioned has to be the Overlay theater's direct child, so
        // IgnorePointer goes inside it rather than around it. The copy must
        // never intercept touches — the spec is explicit that the UI stays
        // usable while this plays.
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: widget.size.width,
          height: widget.size.height,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: scale.clamp(0.0, 2.0),
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: widget.child,
      ),
    );
  }
}
