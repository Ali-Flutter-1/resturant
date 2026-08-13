import 'dart:ui' show ImageFilter, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/theme/app_colors.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/widgets/app_nav_bar.dart';

/// The Flutter tab bar's visual contract.
///
/// This is the bar on Android and web; iOS gets the real `UITabBar`. It follows
/// Material 3's `NavigationBar` metrics, and what is asserted here is the set of
/// things easy to break while changing something else and invisible in a diff:
/// the 64×32 active indicator, one icon size, the outlined-to-filled swap, an
/// edge-to-edge bar with no shadow, and the system inset sitting inside it.
void main() {
  const items = [
    AppNavItem(
      label: 'Menu',
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
    ),
    AppNavItem(
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
          child: AppNavBar(
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

    final bar = tester.getRect(find.byType(AppNavBar));
    final screen = tester.getRect(find.byType(MaterialApp));

    expect(bar.left, screen.left);
    expect(bar.right, screen.right);
    // Flush to the bottom edge: M3 anchors the bar to the screen, with the
    // gesture inset inside it rather than below a hovering pill.
    expect(bar.bottom, screen.bottom);
  });

  testWidgets('draws no shadow and no surrounding border', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AppNavBar),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>();

    expect(decorations, isNotEmpty);
    for (final decoration in decorations) {
      // A hairline stands in for M3's elevation. A drop shadow under an
      // edge-to-edge bar makes it look like a card that touches the bottom.
      expect(decoration.boxShadow, anyOf(isNull, isEmpty));

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

  testWidgets('the selected tab gets M3\'s active indicator and the tint', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(currentIndex: 1));
    await tester.pumpAndSettle();

    // Both indicators are built; the inactive one is scaled down and
    // transparent, so selection can animate rather than pop in.
    final opacities = tester
        .widgetList<AnimatedOpacity>(
          find.descendant(
            of: find.byType(AppNavBar),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((widget) => widget.opacity)
        .toList();
    expect(opacities, containsAll(<double>[1, 0]));

    // Tinted with the app's own accent container, not M3's secondaryContainer:
    // selection should read as the brand crimson.
    final pill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .first;
    expect(pill.color, AppSurfaces.light.accentContainer);

    final accent = AppTheme.light.colorScheme.primary;
    final selected = tester.widget<Icon>(find.byIcon(Icons.receipt_long).first);
    expect(selected.color, accent);
    // ...and the unselected glyph is the outline variant in muted ink.
    final unselected = tester.widget<Icon>(
      find.byIcon(Icons.restaurant_outlined).first,
    );
    expect(unselected.color, isNot(accent));
  });

  testWidgets('the indicator is M3\'s 64 by 32 and icons are one size', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(currentIndex: 1));
    await tester.pumpAndSettle();

    for (final indicator in find.byType(AnimatedOpacity).evaluate()) {
      expect(tester.getSize(find.byWidget(indicator.widget)), const Size(64, 32));
    }

    // One icon size across every tab. A 24 beside a 25 reads as a mistake
    // without ever looking obviously wrong.
    final sizes = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byType(AppNavBar),
            matching: find.byType(Icon),
          ),
        )
        .map((icon) => icon.size);
    expect(sizes, everyElement(24.0));
  });

  testWidgets('the whole cell is the touch target', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final cell = tester.getSize(find.byType(InkResponse).first);
    // Well past the 48pt minimum in both directions.
    expect(cell.height, greaterThanOrEqualTo(48));
    expect(cell.width, greaterThanOrEqualTo(48));

    // A tap near the cell's edge — not on the glyph — still registers.
    final taps = <int>[];
    await tester.pumpWidget(wrap(onTap: taps.add));
    final rect = tester.getRect(find.byType(InkResponse).last);
    await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
    expect(taps, [1]);
  });

  testWidgets('blurs what is behind it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final backdrop = tester.widget<BackdropFilter>(
      find
          .descendant(
            of: find.byType(AppNavBar),
            matching: find.byType(BackdropFilter),
          )
          .first,
    );
    expect(backdrop.filter, isA<ImageFilter>());
  });

  testWidgets('the system inset is inside the bar, not overlapped', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(bottomInset: 34));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byType(AppNavBar));
    final label = tester.getRect(find.text('Menu'));

    // Content sits above the gesture area; the bar itself extends behind it.
    expect(bar.bottom - label.bottom, greaterThanOrEqualTo(34));
    expect(bar.height, AppNavBar.barHeight + 34);
  });

  testWidgets('pads itself where there is no system inset', (tester) async {
    await tester.pumpWidget(wrap(bottomInset: 0));
    await tester.pumpAndSettle();

    // 64 + 16 — M3's 80pt bar, reached the other way round.
    expect(
      tester.getRect(find.byType(AppNavBar)).height,
      AppNavBar.barHeight + AppNavBar.bottomPaddingWithoutInset,
    );
    expect(
      AppNavBar.barHeight + AppNavBar.bottomPaddingWithoutInset,
      80,
    );
  });

  testWidgets('a large text scale does not break the fixed height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.4)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AppNavBar(items: items, currentIndex: 0, onTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Clamped rather than allowed to overflow: the bar's height is fixed, so an
    // unbounded label would push the indicator out of it.
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(AppNavBar)).height,
      AppNavBar.barHeight + AppNavBar.bottomPaddingWithoutInset,
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

    // Selection must reach assistive tech; a tint and a pill are both invisible
    // to it.
    final semantics = tester.getSemantics(find.text('Menu'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('renders in dark theme without exception', (tester) async {
    await tester.pumpWidget(wrap(theme: AppTheme.dark, currentIndex: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
