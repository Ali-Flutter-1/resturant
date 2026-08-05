import 'package:flutter/material.dart';

/// Colour tokens for T's Café.
///
/// Derived from the Figma file `Ap Design`. That file defines no Figma
/// variables or published styles, so these values were extracted from raw
/// fills and regularised into ramps — see the design system reference for the
/// reasoning behind each decision.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Crimson — the brand ramp, built outward from the existing #AF101A.
  // ---------------------------------------------------------------------
  static const crimson50 = Color(0xFFFCF1F1);
  static const crimson100 = Color(0xFFF8DEDF);
  static const crimson200 = Color(0xFFEFB9BC);
  static const crimson300 = Color(0xFFE08C91);
  static const crimson400 = Color(0xFFCE555C);
  static const crimson500 = Color(0xFFC4232C);

  /// Primary. The one value carried over from the design untouched.
  static const crimson600 = Color(0xFFAF101A);
  static const crimson700 = Color(0xFF8E0A13);
  static const crimson800 = Color(0xFF6A070E);
  static const crimson900 = Color(0xFF46050A);

  // ---------------------------------------------------------------------
  // Neutrals — warmed toward the brand hue. Never a pure grey: cold greys
  // sit badly against the cream ground.
  // ---------------------------------------------------------------------
  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral25 = Color(0xFFFBF9F4); // app ground
  static const neutral50 = Color(0xFFF5F0E8);
  static const neutral100 = Color(0xFFE9E1D6);
  static const neutral200 = Color(0xFFD5C9BC);
  static const neutral300 = Color(0xFFB3A498);
  static const neutral400 = Color(0xFF8A7B73);
  static const neutral600 = Color(0xFF5C4F4A);
  static const neutral800 = Color(0xFF332926);
  static const neutral900 = Color(0xFF241C1A); // text, in place of black

  // ---------------------------------------------------------------------
  // Dark-theme grounds. Warm, not neutral — the brand stays legible on them.
  // ---------------------------------------------------------------------
  static const darkGround = Color(0xFF16110F);
  static const darkSurface = Color(0xFF201917);
  static const darkRaised = Color(0xFF292120);
  static const darkLine = Color(0xFF352B29);
  static const darkLineFirm = Color(0xFF453835);
  static const darkInk = Color(0xFFF3ECE4);
  static const darkInkMuted = Color(0xFFBCADA5);
  static const darkInkSoft = Color(0xFF8B7C75);

  /// Crimson 600 is too dark to read on the dark ground; this is its stand-in.
  static const darkAccent = Color(0xFFE4646B);
  static const darkAccentInk = Color(0xFFF09098);
}

/// Semantic colours for order state.
///
/// Held deliberately outside the brand hue: if crimson means "action", it
/// cannot also mean "late".
@immutable
class OrderStateColors extends ThemeExtension<OrderStateColors> {
  const OrderStateColors({
    required this.preparing,
    required this.preparingContainer,
    required this.ready,
    required this.readyContainer,
    required this.served,
    required this.servedContainer,
    required this.overdue,
    required this.overdueContainer,
  });

  final Color preparing;
  final Color preparingContainer;
  final Color ready;
  final Color readyContainer;
  final Color served;
  final Color servedContainer;
  final Color overdue;
  final Color overdueContainer;

  static const light = OrderStateColors(
    preparing: Color(0xFFB0740C),
    preparingContainer: Color(0xFFFDF3E0),
    ready: Color(0xFF2C7A54),
    readyContainer: Color(0xFFE6F3EC),
    served: Color(0xFF6B5D58),
    servedContainer: Color(0xFFF1ECE6),
    overdue: Color(0xFFC4232C),
    overdueContainer: Color(0xFFFBEAEB),
  );

  static const dark = OrderStateColors(
    preparing: Color(0xFFE0A040),
    preparingContainer: Color(0xFF3A2C14),
    ready: Color(0xFF5FBE8C),
    readyContainer: Color(0xFF173428),
    served: Color(0xFFA0938D),
    servedContainer: Color(0xFF2C2523),
    overdue: Color(0xFFEE7A80),
    overdueContainer: Color(0xFF3A1B1D),
  );

  @override
  OrderStateColors copyWith({
    Color? preparing,
    Color? preparingContainer,
    Color? ready,
    Color? readyContainer,
    Color? served,
    Color? servedContainer,
    Color? overdue,
    Color? overdueContainer,
  }) {
    return OrderStateColors(
      preparing: preparing ?? this.preparing,
      preparingContainer: preparingContainer ?? this.preparingContainer,
      ready: ready ?? this.ready,
      readyContainer: readyContainer ?? this.readyContainer,
      served: served ?? this.served,
      servedContainer: servedContainer ?? this.servedContainer,
      overdue: overdue ?? this.overdue,
      overdueContainer: overdueContainer ?? this.overdueContainer,
    );
  }

  @override
  OrderStateColors lerp(OrderStateColors? other, double t) {
    if (other == null) return this;
    return OrderStateColors(
      preparing: Color.lerp(preparing, other.preparing, t)!,
      preparingContainer: Color.lerp(
        preparingContainer,
        other.preparingContainer,
        t,
      )!,
      ready: Color.lerp(ready, other.ready, t)!,
      readyContainer: Color.lerp(readyContainer, other.readyContainer, t)!,
      served: Color.lerp(served, other.served, t)!,
      servedContainer: Color.lerp(servedContainer, other.servedContainer, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      overdueContainer: Color.lerp(
        overdueContainer,
        other.overdueContainer,
        t,
      )!,
    );
  }
}

/// Elevation and the tinted surfaces the ramps enable.
@immutable
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.ground,
    required this.raised,
    required this.line,
    required this.lineFirm,
    required this.inkMuted,
    required this.inkSoft,
    required this.accentContainer,
    required this.restShadow,
    required this.cardShadow,
    required this.ctaShadow,
  });

  final Color ground;
  final Color raised;
  final Color line;
  final Color lineFirm;
  final Color inkMuted;
  final Color inkSoft;

  /// Tinted crimson surface — order badges, selected states.
  final Color accentContainer;

  final List<BoxShadow> restShadow;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> ctaShadow;

  static const light = AppSurfaces(
    ground: AppColors.neutral25,
    raised: AppColors.neutral0,
    line: AppColors.neutral100,
    lineFirm: AppColors.neutral200,
    inkMuted: AppColors.neutral600,
    inkSoft: AppColors.neutral400,
    accentContainer: AppColors.crimson50,
    restShadow: [
      BoxShadow(color: Color(0x0F241C1A), blurRadius: 2, offset: Offset(0, 1)),
    ],
    cardShadow: [
      BoxShadow(color: Color(0x0D241C1A), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x12241C1A), blurRadius: 16, offset: Offset(0, 6)),
    ],
    // Derived from the fill itself. The Figma file shadowed this button with
    // #D32F2F — a red that appears nowhere else in the design.
    ctaShadow: [
      BoxShadow(
        color: Color(0x38AF101A),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );

  static const dark = AppSurfaces(
    ground: AppColors.darkGround,
    raised: AppColors.darkRaised,
    line: AppColors.darkLine,
    lineFirm: AppColors.darkLineFirm,
    inkMuted: AppColors.darkInkMuted,
    inkSoft: AppColors.darkInkSoft,
    accentContainer: Color(0x21E4646B),
    restShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
    ],
    cardShadow: [
      BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6)),
    ],
    ctaShadow: [
      BoxShadow(
        color: Color(0x2EE4646B),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );

  @override
  AppSurfaces copyWith({
    Color? ground,
    Color? raised,
    Color? line,
    Color? lineFirm,
    Color? inkMuted,
    Color? inkSoft,
    Color? accentContainer,
    List<BoxShadow>? restShadow,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? ctaShadow,
  }) {
    return AppSurfaces(
      ground: ground ?? this.ground,
      raised: raised ?? this.raised,
      line: line ?? this.line,
      lineFirm: lineFirm ?? this.lineFirm,
      inkMuted: inkMuted ?? this.inkMuted,
      inkSoft: inkSoft ?? this.inkSoft,
      accentContainer: accentContainer ?? this.accentContainer,
      restShadow: restShadow ?? this.restShadow,
      cardShadow: cardShadow ?? this.cardShadow,
      ctaShadow: ctaShadow ?? this.ctaShadow,
    );
  }

  @override
  AppSurfaces lerp(AppSurfaces? other, double t) {
    if (other == null) return this;
    return AppSurfaces(
      ground: Color.lerp(ground, other.ground, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineFirm: Color.lerp(lineFirm, other.lineFirm, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      restShadow: BoxShadow.lerpList(restShadow, other.restShadow, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      ctaShadow: BoxShadow.lerpList(ctaShadow, other.ctaShadow, t)!,
    );
  }
}

/// Sugar so widgets read `context.surfaces.line` rather than a long lookup.
extension AppThemeAccess on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  AppSurfaces get surfaces => Theme.of(this).extension<AppSurfaces>()!;
  OrderStateColors get orderColors =>
      Theme.of(this).extension<OrderStateColors>()!;
}
