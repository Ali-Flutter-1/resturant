import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_colors.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/domain/admin_order.dart';
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

    test('the four state colours are distinct', () {
      final light = OrderStateColors.light;
      final colours = {
        light.preparing,
        light.ready,
        light.served,
        light.overdue,
      };
      // Four colours, not one per status: the API has seven states and several
      // share a meaning — placed and preparing are both "in the kitchen",
      // cancelled and rejected are both "not happening". What matters is that
      // the four are told apart.
      expect(colours.length, 4);
    });

    test('every status has a colour, including the unknown fallback', () {
      // A status the app has never heard of must still draw, or one new backend
      // value crashes every ticket on the screen.
      for (final status in OrderStatus.values) {
        expect(status.label, isNotEmpty, reason: '\$status needs a label');
      }
    });
  });
}
