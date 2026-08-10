import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The size steps money and headings share.
///
/// Prices used to take a free `double`, and the call sites drifted to nine
/// different values — including one row that never passed a size at all and
/// silently rendered at the 32px default next to 15px text. The scale is
/// closed so a price can only land on a step a heading already occupies.
enum MoneySize {
  /// Checkout totals and the headline figure on a dashboard card.
  hero(28),

  /// Secondary dashboard figures.
  large(24),

  /// The price on a dish card — the most common case.
  medium(18),

  /// Amounts inside list rows.
  small(16),

  /// Dense admin tables and reference codes.
  compact(14);

  const MoneySize(this.size);

  final double size;
}

/// The type scale.
///
/// Two families, as in the design: Libre Caslon Text carries headings and
/// every currency figure — money set in the display face is what makes a menu
/// read as a menu — while Hanken Grotesk handles everything operational.
///
/// Both are bundled variable fonts (see `pubspec.yaml`). Weight is selected
/// through the `wght` axis rather than by loading separate static files, so
/// `fontWeight` alone would be ignored — [_weight] sets both, and [withWeight]
/// is the only safe way to change weight after the fact.
///
/// Tracking follows the direction Apple's SF table and the Material 3 scale
/// both take: negative as type grows, easing back through zero around 15–16px,
/// positive only for small or uppercase text, which needs the air.
abstract final class AppTypography {
  static const _display = 'LibreCaslonText';
  static const _body = 'HankenGrotesk';

  /// Variable fonts need the axis set explicitly; `fontWeight` is kept in step
  /// so anything reading the style back still sees the right value.
  static List<FontVariation> _weight(FontWeight weight) => [
    FontVariation('wght', weight.value.toDouble()),
  ];

  static TextStyle _style({
    required String family,
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: features,
    );
  }

  static TextStyle displayStyle(Color ink) => _style(
    family: _display,
    size: 28,
    lineHeight: 36,
    weight: FontWeight.w700,
    letterSpacing: -0.4,
    color: ink,
  );

  static TextStyle titleStyle(Color ink) => _style(
    family: _display,
    size: 22,
    lineHeight: 28,
    weight: FontWeight.w700,
    letterSpacing: -0.25,
    color: ink,
  );

  static TextStyle headlineStyle(Color ink) => _style(
    family: _display,
    size: 18,
    lineHeight: 24,
    weight: FontWeight.w700,
    letterSpacing: -0.15,
    color: ink,
  );

  /// Currency.
  ///
  /// [tabular] gives every glyph the same advance width so a column of prices
  /// stays aligned as values change through service — right for lists, wrong
  /// for a single headline figure, where it forces full-width commas and
  /// stops and reads as "£24 , 500 . 00".
  static TextStyle money(
    Color ink, {
    MoneySize size = MoneySize.medium,
    bool tabular = true,
  }) {
    final points = size.size;
    return _style(
      family: _display,
      size: points,
      lineHeight: points * 1.25,
      weight: FontWeight.w700,
      // Figures set large need the same tightening headings get.
      letterSpacing: points >= MoneySize.large.size ? -0.3 : null,
      color: ink,
      features: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// The single letter standing in for a dish photo that has not loaded.
  ///
  /// Decorative rather than informational, so it sits off the text scale.
  static TextStyle monogram(Color ink) => _style(
    family: _display,
    size: 34,
    lineHeight: 40,
    weight: FontWeight.w700,
    letterSpacing: -0.5,
    color: ink,
  );

  static TextStyle bodyStyle(Color ink) => _style(
    family: _body,
    size: 16,
    lineHeight: 24,
    weight: FontWeight.w400,
    color: ink,
  );

  static TextStyle subtleStyle(Color ink) => _style(
    family: _body,
    size: 14,
    lineHeight: 20,
    weight: FontWeight.w400,
    letterSpacing: 0.1,
    color: ink,
  );

  /// Buttons and links.
  ///
  /// Mixed case at every call site, so this carries none of the wide tracking
  /// the uppercase styles below want.
  static TextStyle labelStyle(Color ink) => _style(
    family: _body,
    size: 14,
    lineHeight: 20,
    weight: FontWeight.w600,
    letterSpacing: 0.1,
    color: ink,
  );

  /// Uppercase eyebrows — "TOTAL REVENUE", status text.
  static TextStyle caption(Color ink) => _style(
    family: _body,
    size: 12,
    lineHeight: 16,
    weight: FontWeight.w600,
    letterSpacing: 0.96,
    color: ink,
  );

  /// Tab bar labels.
  ///
  /// Sat at 10px behind two separate `copyWith(fontSize: 10)` calls, which also
  /// left [caption]'s uppercase tracking on text that is not uppercase. 11px is
  /// the floor Apple sets for a tab label.
  static TextStyle navLabel(Color ink) => _style(
    family: _body,
    size: 11,
    lineHeight: 14,
    weight: FontWeight.w600,
    letterSpacing: 0.2,
    color: ink,
  );

  /// The count on the cart badge, and anything else where digits sit in a pill
  /// too small for a text style.
  static TextStyle badge(Color ink) => _style(
    family: _body,
    size: 11,
    lineHeight: 14,
    weight: FontWeight.w700,
    letterSpacing: 0.2,
    color: ink,
    features: const [FontFeature.tabularFigures()],
  );

  static TextTheme textTheme({required Color ink, required Color muted}) {
    return TextTheme(
      displayLarge: displayStyle(ink),
      displayMedium: _style(
        family: _display,
        size: 24,
        lineHeight: 32,
        weight: FontWeight.w700,
        letterSpacing: -0.3,
        color: ink,
      ),
      headlineLarge: titleStyle(ink),
      headlineMedium: headlineStyle(ink),
      titleLarge: headlineStyle(ink),
      titleMedium: _style(
        family: _body,
        size: 15,
        lineHeight: 20,
        weight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: bodyStyle(ink),
      bodyMedium: subtleStyle(muted),
      bodySmall: _style(
        family: _body,
        size: 13,
        lineHeight: 18,
        weight: FontWeight.w400,
        letterSpacing: 0.15,
        color: muted,
      ),
      labelLarge: labelStyle(ink),
      labelMedium: caption(muted),
      labelSmall: _style(
        family: _body,
        size: 11,
        lineHeight: 16,
        weight: FontWeight.w600,
        letterSpacing: 0.88,
        color: muted,
      ),
    );
  }

  static TextTheme get lightTextTheme =>
      textTheme(ink: AppColors.neutral900, muted: AppColors.neutral600);

  static TextTheme get darkTextTheme =>
      textTheme(ink: AppColors.darkInk, muted: AppColors.darkInkMuted);
}

extension AppTextStyleWeight on TextStyle {
  /// Re-weights a style from the scale.
  ///
  /// Both families are variable fonts, and `fontVariations` wins over
  /// `fontWeight` when it pins the `wght` axis — which every style here does.
  /// So `copyWith(fontWeight: ...)` renders no differently from the style it
  /// was called on, which is how several selected states ended up looking
  /// identical to their unselected ones. This moves the axis too.
  TextStyle withWeight(FontWeight weight) => copyWith(
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
  );
}
