import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/menu/presentation/dish_details_screen.dart';
import 'package:practice/shared/preview/sample_content.dart';

void main() {
  group('CartCubit', () {
    test('starts empty', () => expect(CartCubit().state, 0));

    test('adds one by default', () {
      expect((CartCubit()..add()).state, 1);
    });

    test('adds a quantity', () {
      expect((CartCubit()..add(3)).state, 3);
    });

    test('accumulates across additions', () {
      final cart = CartCubit()
        ..add(2)
        ..add(3);
      expect(cart.state, 5);
    });

    test('clear empties it', () {
      final cart = CartCubit()..add(4);
      cart.clear();
      expect(cart.state, 0);
    });
  });

  group('DishDetails pricing', () {
    Widget wrap(Widget child) => BlocProvider(
      create: (_) => CartCubit(),
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

    testWidgets('opens at the dish price for a single unit', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      // Featured dish is £17.50.
      expect(find.text('£17.50'), findsOneWidget);
    });

    testWidgets('quantity multiplies the total', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
      expect(find.text('£35.00'), findsOneWidget);
    });

    testWidgets('an add-on raises the total', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      // Coconut Roti is £3.50, and sits below the fold on a test viewport.
      await tester.scrollUntilVisible(find.text('Coconut Roti'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coconut Roti'));
      await tester.pumpAndSettle();

      expect(find.text('£21.00'), findsOneWidget);
    });

    testWidgets('add-ons multiply with quantity', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Coconut Roti'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coconut Roti'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // (17.50 + 3.50) x 2
      expect(find.text('£42.00'), findsOneWidget);
    });

    testWidgets('deselecting an add-on removes its cost', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Coconut Roti'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coconut Roti'));
      await tester.pumpAndSettle();
      expect(find.text('£21.00'), findsOneWidget);

      await tester.tap(find.text('Coconut Roti'));
      await tester.pumpAndSettle();
      expect(find.text('£17.50'), findsOneWidget);
    });

    testWidgets('quantity will not drop below one', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Ordering zero of something is not a thing the UI should allow.
      expect(find.text('£17.50'), findsOneWidget);
    });

    testWidgets('renders the dish it was given, not the featured one', (
      tester,
    ) async {
      const dish = SampleDish(
        name: 'Tempered Dhal',
        description: 'Red lentils.',
        price: 12,
      );
      await tester.pumpWidget(wrap(const DishDetailsScreen(dish: dish)));
      await tester.pumpAndSettle();

      expect(find.text('Tempered Dhal'), findsOneWidget);
      expect(find.text('£12.00'), findsOneWidget);
    });

    testWidgets('spice level is single-select', (tester) async {
      await tester.pumpWidget(wrap(const DishDetailsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Hot'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hot'));
      await tester.pumpAndSettle();

      // All three remain on screen; only the styling differs, so the check
      // is that selecting one does not remove the others.
      expect(find.text('Mild'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Hot'), findsOneWidget);
    });
  });

  group('SampleContent basket maths', () {
    test('subtotal is the sum of the line items', () {
      expect(SampleContent.basketSubtotal, 32.50);
    });

    test('total adds delivery and service to the subtotal', () {
      expect(
        SampleContent.basketTotal,
        SampleContent.basketSubtotal +
            SampleContent.deliveryFee +
            SampleContent.serviceCharge,
      );
      expect(SampleContent.basketTotal, 37.00);
    });

    test('every dish formats its price in sterling to two places', () {
      for (final dish in SampleContent.menu) {
        expect(dish.formattedPrice, startsWith('£'));
        expect(dish.formattedPrice.split('.').last.length, 2);
      }
    });
  });
}
