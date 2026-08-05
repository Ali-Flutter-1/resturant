import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Two families, as in the design: Libre Caslon Text carries headings and
/// every currency figure — money set in the display face is what makes a menu
/// read as a menu — while Hanken Grotesk handles everything operational.
///
/// Both are bundled variable fonts (see `pubspec.yaml`). Weight is selected
/// through the `wght` axis rather than by loading separate static files, so
/// `fontWeight` alone would be ignored — [_weight] sets both.
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
    letterSpacing: 0.7,
    color: ink,
  );

  static TextStyle titleStyle(Color ink) => _style(
    family: _display,
    size: 22,
    lineHeight: 28,
    weight: FontWeight.w700,
    color: ink,
  );

  static TextStyle headlineStyle(Color ink) => _style(
    family: _display,
    size: 18,
    lineHeight: 24,
    weight: FontWeight.w700,
    color: ink,
  );

  /// Currency.
  ///
  /// [tabular] gives every glyph the same advance width so a column of prices
  /// stays aligned as values change through service — right for lists, wrong
  /// for a single headline figure, where it forces full-width commas and
  /// stops and reads as "£24 , 500 . 00".
  static TextStyle money(Color ink, {double size = 32, bool tabular = true}) =>
      _style(
        family: _display,
        size: size,
        lineHeight: size * 1.25,
        weight: FontWeight.w700,
        color: ink,
        features: tabular ? const [FontFeature.tabularFigures()] : null,
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
    color: ink,
  );

  /// Buttons and links.
  static TextStyle labelStyle(Color ink) => _style(
    family: _body,
    size: 14,
    lineHeight: 20,
    weight: FontWeight.w600,
    letterSpacing: 0.7,
    color: ink,
  );

  /// Uppercase eyebrows — "TOTAL REVENUE", nav labels, status text.
  static TextStyle caption(Color ink) => _style(
    family: _body,
    size: 12,
    lineHeight: 16,
    weight: FontWeight.w600,
    letterSpacing: 0.96,
    color: ink,
  );

  static TextTheme textTheme({required Color ink, required Color muted}) {
    return TextTheme(
      displayLarge: displayStyle(ink),
      displayMedium: _style(
        family: _display,
        size: 24,
        lineHeight: 32,
        weight: FontWeight.w700,
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
