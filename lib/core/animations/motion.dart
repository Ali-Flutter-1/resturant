import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Durations and curves live here rather than inline at call sites, so the
/// app's motion can be retuned in one place. Aim is polished Material 3
/// motion — a premium food-delivery feel, not showcase choreography.
abstract final class Motion {
  // Durations ------------------------------------------------------------
  /// Pressed states, ripples, colour shifts.
  static const instant = Duration(milliseconds: 120);

  /// The default. Most state changes and small reveals.
  static const quick = Duration(milliseconds: 220);

  /// Route transitions, sheet entry.
  static const moderate = Duration(milliseconds: 350);

  /// Hero flights and the welcome sequence, where the eye is meant to follow.
  static const slow = Duration(milliseconds: 500);

  /// Shimmer sweeps and other ambient loops.
  static const ambient = Duration(milliseconds: 1200);

  // Curves ---------------------------------------------------------------
  /// Entering the screen: fast out, settle gently.
  static const enter = Curves.easeOutCubic;

  /// Leaving: accelerate away, no lingering.
  static const exit = Curves.easeInCubic;

  /// Both ends — position changes on elements already on screen.
  static const standard = Curves.easeInOutCubic;

  /// A touch of overshoot. Reserve for moments of confirmation, never lists.
  static const emphasised = Curves.easeOutBack;

  // Stagger --------------------------------------------------------------
  /// Gap between successive items in a list reveal.
  static const stagger = Duration(milliseconds: 60);

  /// Cap on staggered items. Beyond this the last item feels late, so
  /// everything after it should appear with the cap.
  static const int staggerCap = 8;

  /// Delay for the item at [index] in a staggered reveal.
  static Duration staggerFor(int index) =>
      stagger * (index.clamp(0, staggerCap));
}
