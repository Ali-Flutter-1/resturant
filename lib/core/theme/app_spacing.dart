/// Spacing, radius and layout constants.
///
/// A 4px base. The Figma export contained values like 1.05, 5 and 6.17 —
/// artifacts of a web export rather than decisions — so everything is snapped
/// to the scale below.
abstract final class AppSpacing {
  static const double x1 = 4; // icon-to-label, tight pairs
  static const double x2 = 8; // within a component
  static const double x3 = 12; // list row padding
  static const double x4 = 16; // card padding, button y-padding, stack gap
  static const double x5 = 20; // screen gutter
  static const double x6 = 24;
  static const double x8 = 32; // between content blocks
  static const double x12 = 48; // section breaks, bottom safe area

  /// Horizontal screen gutter, used by every screen.
  static const double gutter = x5;
}

abstract final class AppRadius {
  static const double xs = 4; // swatches, tiny indicators
  static const double sm = 8; // badges, inputs
  static const double md = 12; // buttons, list cards
  static const double lg = 16; // dashboard metric cards
  static const double pill = 999;
}

/// The icon scale.
///
/// Every glyph in the app snaps to one of these. Before this existed there
/// were fourteen distinct icon sizes across fifty-one icons — 11, 13, 14, 15,
/// 16, 17, 18, 19, 20, 22, 30, 40, 42, 44 — which is what makes rows look
/// subtly misaligned even when their padding is identical: a 17pt glyph beside
/// a 19pt one reads as a mistake without ever looking obviously wrong.
///
/// Each size is paired with the text it sits beside, because an icon's job is
/// to match the line it belongs to rather than to be a size of its own.
abstract final class AppIconSize {
  static const double xs = 12; // beside labelSmall / caption
  static const double sm = 14; // beside bodySmall
  static const double md = 16; // beside bodyMedium, dense actions
  static const double lg = 18; // the default action glyph
  static const double xl = 20; // prominent actions, app bar
  static const double xxl = 28; // decorative markers
  static const double hero = 40; // empty states and placeholders
}

/// The design's reference viewport. Every frame in the Figma file is 390 wide.
abstract final class AppLayout {
  static const double designWidth = 390;
  static const double designHeight = 844;
}
