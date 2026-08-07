import 'package:flutter/material.dart';

import 'motion.dart';

/// Fades content in while it travels a short distance into place.
///
/// This is the app's single entrance animation. It exists as a widget rather
/// than a `flutter_animate` chain because `flutter_animate` has no awareness
/// of the platform's reduce-motion setting — an `.animate().fadeIn().slideY()`
/// runs identically whether or not the user has asked the system to stop
/// moving things. Routing every entrance through here means the preference is
/// honoured once, in [MotionScheme], instead of being forgotten at each call
/// site.
///
/// The slide is deliberately small. The fade carries the reveal; the
/// displacement only lends it a direction, telling the eye where the content
/// came from.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.base,
    this.direction = AxisDirection.up,
    this.distance,
    this.scaleFrom = 1,
  });

  /// A reveal for the item at [index] in a list or grid, delayed by the
  /// standard stagger and capped so long lists don't crawl.
  Reveal.item({
    super.key,
    required int index,
    required this.child,
    Duration extraDelay = Duration.zero,
    this.duration = Motion.base,
    this.direction = AxisDirection.up,
    this.distance,
    this.scaleFrom = 1,
  }) : delay = extraDelay + Motion.staggerFor(index);

  final Widget child;

  /// How long to wait before starting. Used for staggering and for ordering
  /// a screen's sections top to bottom.
  final Duration delay;

  final Duration duration;

  /// Where the content travels *from*: [AxisDirection.up] means it rises into
  /// place from below, which is the default for content arriving on a screen.
  final AxisDirection direction;

  /// Travel distance in logical pixels. Defaults to the [Motion.slideUp]
  /// token; pass zero for content that should only fade.
  final double? distance;

  /// Scale to grow from as the content lands. Above 1 it settles *inward*,
  /// which suits a full-bleed photograph — the image appears to come to rest
  /// rather than to zoom. Leave at 1 for everything else: scaling text and
  /// cards on entry is the sort of decoration this system exists to avoid.
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  // One controller spanning delay plus reveal, with the reveal confined to
  // the tail by an Interval. A timer would do the same job but would need
  // cancelling on dispose, and a stray timer firing into a disposed State is
  // exactly the kind of leak this avoids having to think about.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delayFraction, 1, curve: Motion.enter),
  );

  double get _delayFraction {
    final total = (widget.delay + widget.duration).inMicroseconds;
    if (total == 0) return 0;
    return widget.delay.inMicroseconds / total;
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce-motion skips the choreography entirely: the content is simply
    // already there. Jumping the controller to its end rather than never
    // running it keeps the widget tree identical in both modes.
    if (context.motion.reduced) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    if (motion.reduced) return widget.child;

    Widget content = widget.child;

    if (widget.scaleFrom != 1) {
      content = ScaleTransition(
        scale: Tween<double>(
          begin: widget.scaleFrom,
          end: 1,
        ).animate(_progress),
        child: content,
      );
    }

    final distance = widget.distance ?? motion.slideUp;
    if (distance != 0) {
      content = SlideUpTransition(
        progress: _progress,
        distance: distance,
        direction: widget.direction,
        child: content,
      );
    }

    // Independently animating subtree — a staggered grid would otherwise
    // repaint its siblings on every frame of every item's reveal.
    return RepaintBoundary(
      child: FadeTransition(opacity: _progress, child: content),
    );
  }
}

/// Trailing-position sugar for [Reveal].
///
/// Entrance choreography reads better appended to the widget it applies to
/// than wrapped around it, especially where a screen lists its sections in
/// order and the delays should be legible as a sequence.
extension RevealExtension on Widget {
  /// Reveals this widget after [delay].
  Widget reveal({
    Duration delay = Duration.zero,
    Duration duration = Motion.base,
    AxisDirection direction = AxisDirection.up,
    double? distance,
    double scaleFrom = 1,
  }) => Reveal(
    delay: delay,
    duration: duration,
    direction: direction,
    distance: distance,
    scaleFrom: scaleFrom,
    child: this,
  );

  /// Reveals this widget as item [index] of a staggered list or grid.
  ///
  /// [after] offsets the whole run, for a list that should wait for the
  /// header above it to land first.
  Widget revealItem(
    int index, {
    Duration after = Duration.zero,
    Duration duration = Motion.base,
    AxisDirection direction = AxisDirection.up,
    double? distance,
  }) => Reveal.item(
    index: index,
    extraDelay: after,
    duration: duration,
    direction: direction,
    distance: distance,
    child: this,
  );
}

/// Staggers a fixed list of children, for the `children: [...]` of a column
/// whose sections should land top to bottom.
extension RevealListExtension on List<Widget> {
  /// Reveals each child in turn, one stagger step apart.
  List<Widget> revealStaggered({
    Duration after = Duration.zero,
    Duration duration = Motion.base,
    AxisDirection direction = AxisDirection.up,
  }) => [
    for (final (index, child) in indexed)
      child.revealItem(
        index,
        after: after,
        duration: duration,
        direction: direction,
      ),
  ];
}

/// Translates its child by a distance in logical pixels as [progress] runs
/// 0 → 1, arriving at zero offset.
///
/// [SlideTransition] measures its offset as a fraction of the child's own
/// size, which makes a "16px rise" mean something different for a chip than
/// for a full-bleed hero card. This keeps the displacement absolute so the
/// token means what it says.
///
/// Being an [AnimatedWidget] rather than an [AnimatedBuilder], the child is
/// captured once at construction and never rebuilt by the animation — only
/// the transform is re-evaluated per frame.
class SlideUpTransition extends AnimatedWidget {
  const SlideUpTransition({
    super.key,
    required Animation<double> progress,
    required this.distance,
    required this.child,
    this.direction = AxisDirection.up,
  }) : super(listenable: progress);

  final double distance;
  final AxisDirection direction;
  final Widget child;

  Animation<double> get _progress => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final remaining = (1 - _progress.value) * distance;
    final offset = switch (direction) {
      AxisDirection.up => Offset(0, remaining),
      AxisDirection.down => Offset(0, -remaining),
      AxisDirection.left => Offset(remaining, 0),
      AxisDirection.right => Offset(-remaining, 0),
    };
    return Transform.translate(offset: offset, child: child);
  }
}
