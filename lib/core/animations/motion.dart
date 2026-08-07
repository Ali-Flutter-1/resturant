import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Durations, curves and displacements live here rather than inline at call
/// sites, so the app's motion can be retuned in one place. Aim is polished
/// Material 3 motion — a premium food-delivery feel, not showcase
/// choreography.
///
/// Read these through [Motion.of] wherever a `BuildContext` is available: the
/// returned [MotionScheme] folds in the platform's reduce-motion setting, so
/// accessibility is handled here and not re-litigated at every call site. The
/// raw constants below are the design intent; the scheme is what should
/// actually drive a widget.
abstract final class Motion {
  // Durations ------------------------------------------------------------
  /// Pressed states, ripples, colour shifts. Below ~100ms reads as instant.
  static const instant = Duration(milliseconds: 100);

  /// Small reveals and swaps that shouldn't draw the eye.
  static const fast = Duration(milliseconds: 200);

  /// The default. Most state changes, route transitions, sheet entry.
  static const base = Duration(milliseconds: 300);

  /// Hero flights and the welcome sequence, where the eye is meant to follow.
  /// Nothing on a repeated path may exceed this.
  static const slow = Duration(milliseconds: 450);

  /// Ambient loops — shimmer sweeps. Not a transition, so the 500ms ceiling
  /// on repeated-path motion doesn't apply: nobody waits on a loop.
  static const ambient = Duration(milliseconds: 1200);

  // Curves ---------------------------------------------------------------
  /// Entering the screen: fast out, settle gently.
  static const enter = Curves.easeOutCubic;

  /// Leaving: accelerate away, no lingering.
  static const exit = Curves.easeInCubic;

  /// Both ends — position changes on elements already on screen, and the
  /// standard M3 transition curve.
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Symmetric ease without the emphasised overshoot in velocity. For
  /// continuous, reversible changes such as a press settling back.
  static const standard = Curves.easeInOutCubic;

  /// A touch of overshoot. Reserve for moments of confirmation, never lists —
  /// overshoot on a grid reads as instability, not delight.
  static const playful = Curves.easeOutBack;

  // Displacement ---------------------------------------------------------
  /// How far a revealing element travels upward into place. Small on purpose:
  /// the fade carries the reveal, the slide only gives it a direction.
  static const slideUp = 16.0;

  /// Lateral travel for elements entering from the side of the viewport.
  static const slideIn = 24.0;

  /// How far a tappable surface depresses under the finger.
  static const pressScale = 0.96;

  /// Large surfaces — full-bleed cards, images — want less. The same 4% on a
  /// 300pt card is a much bigger absolute movement than on a 44pt button.
  static const pressScaleLarge = 0.98;

  // Stagger --------------------------------------------------------------
  /// Gap between successive items in a list reveal.
  static const stagger = Duration(milliseconds: 40);

  /// Cap on staggered items. Beyond this the last item feels late, so
  /// everything after it appears together with the item at the cap.
  static const int staggerCap = 8;

  /// Delay for the item at [index] in a staggered reveal.
  static Duration staggerFor(int index) =>
      stagger * (index.clamp(0, staggerCap));

  /// A slower cadence, for one-time full-screen sequences such as the welcome
  /// splash. The list stagger is tuned for content the user is waiting to
  /// act on; a splash is content they are meant to look at, and the same
  /// 40ms beat there reads as hurried rather than composed.
  static const cinematicStagger = Duration(milliseconds: 140);

  /// Delay for step [index] of a cinematic sequence.
  static Duration cinematicFor(int index) =>
      cinematicStagger * (index.clamp(0, staggerCap));

  /// The motion scheme for [context], with reduce-motion already resolved.
  static MotionScheme of(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduced =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    return reduced ? const MotionScheme.reduced() : const MotionScheme();
  }
}

/// [Motion] with the platform's reduce-motion preference applied.
///
/// The distinction that matters for accessibility is not *how long* an
/// animation runs but *whether pixels travel*. Vestibular triggers come from
/// movement, scaling and parallax — not from opacity. So under reduce-motion
/// this collapses displacement to zero and movement durations to nothing,
/// while still permitting a brief cross-fade so state changes remain legible
/// rather than snapping.
@immutable
class MotionScheme {
  const MotionScheme() : reduced = false;

  const MotionScheme.reduced() : reduced = true;

  /// Whether the platform has asked for reduced motion.
  final bool reduced;

  /// Duration for a transition that displaces pixels — slides, scales,
  /// parallax, shared-element flights. Collapses to nothing when reduced.
  Duration move(Duration duration) => reduced ? Duration.zero : duration;

  /// Duration for an opacity-only change. Kept brief but never removed: a
  /// cross-fade is safe under reduce-motion and a hard cut is harder to read.
  Duration fade(Duration duration) => reduced ? Motion.instant : duration;

  /// Curve for entering content. Linear under reduce-motion, since easing
  /// only shapes movement that is no longer happening.
  Curve get enter => reduced ? Curves.linear : Motion.enter;

  Curve get exit => reduced ? Curves.linear : Motion.exit;

  Curve get emphasized => reduced ? Curves.linear : Motion.emphasized;

  Curve get standard => reduced ? Curves.linear : Motion.standard;

  /// Overshoot is movement by definition, so it degrades to a plain ease.
  Curve get playful => reduced ? Curves.linear : Motion.playful;

  /// Upward travel for a revealing element, in logical pixels.
  double get slideUp => reduced ? 0 : Motion.slideUp;

  double get slideIn => reduced ? 0 : Motion.slideIn;

  /// Depression scale for a pressed surface. Unity when reduced — the press
  /// still registers, it simply doesn't move.
  double get pressScale => reduced ? 1 : Motion.pressScale;

  double get pressScaleLarge => reduced ? 1 : Motion.pressScaleLarge;

  /// Per-item delay in a staggered reveal. Reduced motion shows the whole
  /// list at once: a stagger is a sequence of movements.
  Duration staggerFor(int index) =>
      reduced ? Duration.zero : Motion.staggerFor(index);
}

/// Sugar for `Motion.of(context)`, which reads badly inline in a build method.
extension MotionContext on BuildContext {
  MotionScheme get motion => Motion.of(this);
}
