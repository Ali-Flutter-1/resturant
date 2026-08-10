import 'dart:ui' show ImageFilter, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/widgets/flutter_glass_nav_bar.dart';

/// The Flutter tab bar's visual contract.
///
/// This is the bar on Android and web, and its whole purpose is to pass for
/// UIKit's. The assertions below are the specific things that made it read as a
/// Material `NavigationBar` — a floating card, a shadow, a pill behind the
/// selected icon, an ink ripple. Each one is easy to reintroduce by accident
/// while changing something else, and none of them is visible in a diff.
void main() {
  const items = [
    FlutterGlassNavItem(
      label: 'Menu',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
    ),
    FlutterGlassNavItem(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
  ];

  Widget wrap({
    int currentIndex = 0,
    ValueChanged<int>? onTap,
    ThemeData? theme,
    double bottomInset = 34,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FlutterGlassNavBar(
            items: items,
            currentIndex: currentIndex,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('spans the full width — it is not a floating card', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(FlutterGlassNavBar));
    final screen = tester.getRect(find.byType(MaterialApp));

    expect(bar.left, screen.left);
    expect(bar.right, screen.right);
    // Flush to the bottom edge: the home indicator sits inside the bar rather
    // than below a hovering pill.
    expect(bar.bottom, screen.bottom);
  });

  testWidgets('draws no shadow and no surrounding border', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(FlutterGlassNavBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();

    expect(decorations, isNotEmpty);
    for (final decoration in decorations) {
      // Depth comes from translucency. A drop shadow under an edge-to-edge bar
      // is what makes it look like a card that happens to touch the bottom.
      expect(decoration.boxShadow, anyOf(isNull, isEmpty));

      // A hairline along the top only — never a box around the whole bar.
      final border = decoration.border;
      if (border != null) {
        expect(border, isA<Border>());
        final sides = border as Border;
        expect(sides.left, BorderSide.none);
        expect(sides.right, BorderSide.none);
        expect(sides.bottom, BorderSide.none);
        expect(sides.top.width, lessThanOrEqualTo(0.5));
      }
    }
  });

  testWidgets('the selected tab is a tint, not a filled container', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(currentIndex: 1));
    await tester.pumpAndSettle();

    // No painted ground anywhere behind an icon: the pill was the single most
    // Android thing about the old bar.
    final grounds = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byType(FlutterGlassNavBar),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .toList();
    expect(grounds, isEmpty);

    final accent = AppTheme.light.colorScheme.primary;
    final selected = tester.widget<Icon>(find.byIcon(Icons.receipt_long).first);
    expect(selected.color, accent);

    // ...and the unselected glyph is the outline variant in muted ink.
    final unselected = tester.widget<Icon>(
      find.byIcon(Icons.restaurant_outlined).first,
    );
    expect(unselected.color, isNot(accent));
  });

  testWidgets('press feedback dims rather than rippling', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // An InkWell's splash is unmistakably Material, whatever colour it is.
    expect(
      find.descendant(
        of: find.byType(FlutterGlassNavBar),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Orders')),
    );
    await tester.pump(const Duration(milliseconds: 150));

    final dimmed = tester
        .widgetList<AnimatedOpacity>(
          find.descendant(
            of: find.byType(FlutterGlassNavBar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((widget) => widget.opacity);
    expect(dimmed, contains(lessThan(1.0)));

    await gesture.up();
    await tester.pumpAndSettle();

    final restored = tester
        .widgetList<AnimatedOpacity>(
          find.descendant(
            of: find.byType(FlutterGlassNavBar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((widget) => widget.opacity);
    expect(restored, everyElement(1.0));
  });

  testWidgets('blurs what is behind it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final backdrop = tester.widget<BackdropFilter>(
      find
          .descendant(
            of: find.byType(FlutterGlassNavBar),
            matching: find.byType(BackdropFilter),
          )
          .first,
    );
    expect(backdrop.filter, isA<ImageFilter>());
  });

  testWidgets('the home indicator is inset inside the bar, not overlapped', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(bottomInset: 34));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(FlutterGlassNavBar));
    final label = tester.getRect(find.text('Menu'));

    // Content sits above the indicator area; the bar itself extends behind it.
    expect(bar.bottom - label.bottom, greaterThanOrEqualTo(34));
    expect(bar.height, FlutterGlassNavBar.barHeight + 34);
  });

  testWidgets('pads itself where there is no home indicator', (tester) async {
    await tester.pumpWidget(wrap(bottomInset: 0));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(FlutterGlassNavBar)).height,
      FlutterGlassNavBar.barHeight +
          FlutterGlassNavBar.bottomPaddingWithoutInset,
    );
  });

  testWidgets('reports taps and stays keyboard/screen-reader legible', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(wrap(onTap: taps.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    expect(taps, [1]);

    // Selection must reach assistive tech; a tint alone is invisible to it.
    final semantics = tester.getSemantics(find.text('Menu'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('renders in dark theme without exception', (tester) async {
    await tester.pumpWidget(wrap(theme: AppTheme.dark, currentIndex: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
