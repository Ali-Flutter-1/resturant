import 'package:flutter/services.dart';

/// Haptic vocabulary.
///
/// Calls live here rather than inline so the app speaks with one physical
/// voice — and so intensity is chosen by *what the action means*, not by
/// whichever constant came to mind at the call site. Uniform buzzing on every
/// tap reads as cheap; graded feedback reads as considered.
///
/// The scale, quietest to firmest:
///
///  * [selection] — moving through options. Picking a spice level, a filter,
///    a date. Nothing is committed.
///  * [toggle] — flipping a binary. Favourite on, dish availability off.
///  * [commit] — an action with consequences. Add to cart, place order,
///    confirm a reservation, sign in.
///  * [success] / [failure] — the outcome of a commit, once it is known.
///
/// Android maps these onto a coarser set than iOS; that is expected and
/// preferable to hand-rolling patterns per platform. The OS honours the
/// user's system-wide haptics setting, and the platform channel is a no-op
/// under `flutter test`, so there is nothing to gate here.
abstract final class AppHaptics {
  /// Moving between options.
  static void selection() => HapticFeedback.selectionClick();

  /// Flipping something on or off.
  static void toggle() => HapticFeedback.lightImpact();

  /// An action the user cannot casually undo.
  static void commit() => HapticFeedback.mediumImpact();

  /// A commit that worked.
  static void success() => HapticFeedback.mediumImpact();

  /// A commit that did not. Firmer, because it needs to interrupt.
  static void failure() => HapticFeedback.heavyImpact();
}
