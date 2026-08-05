import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_colors.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/widgets/status_pill.dart';

void main() {
  group('theme', () {
    test('light theme carries both custom extensions', () {
      final theme = AppTheme.light;
      expect(theme.extension<AppSurfaces>(), isNotNull);
      expect(theme.extension<OrderStateColors>(), isNotNull);
    });

    test('dark theme carries both custom extensions', () {
      final theme = AppTheme.dark;
      expect(theme.extension<AppSurfaces>(), isNotNull);
      expect(theme.extension<OrderStateColors>(), isNotNull);
    });

    test('primary stays exactly the crimson taken from the design', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.crimson600);
    });

    test('dark theme substitutes a legible accent for the dark ground', () {
      // Crimson 600 is too dark to read on #16110F, so the dark theme must
      // not reuse it.
      expect(AppTheme.dark.colorScheme.primary, isNot(AppColors.crimson600));
      expect(AppTheme.dark.colorScheme.primary, AppColors.darkAccent);
    });
  });

  group('StatusPill', () {
    Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('renders the status label in upper case', (tester) async {
      await tester.pumpWidget(
        wrap(const StatusPill(status: OrderStatus.preparing)),
      );
      expect(find.text('PREPARING'), findsOneWidget);
    });

    testWidgets('resolves its colours in both themes', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          wrap(const StatusPill(status: OrderStatus.ready), theme: theme),
        );
        expect(find.text('READY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    test('every status maps to a distinct foreground colour', () {
      final light = OrderStateColors.light;
      final colours = {
        light.preparing,
        light.ready,
        light.served,
        light.overdue,
      };
      expect(colours.length, OrderStatus.values.length);
    });
  });
}
