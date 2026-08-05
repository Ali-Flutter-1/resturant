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
  static const double sm = 8; // badges, inputs
  static const double md = 12; // buttons, list cards
  static const double lg = 16; // dashboard metric cards
  static const double pill = 999;
}

/// The design's reference viewport. Every frame in the Figma file is 390 wide.
abstract final class AppLayout {
  static const double designWidth = 390;
  static const double designHeight = 844;
}
