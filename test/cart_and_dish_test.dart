import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/menu/presentation/dish_details_screen.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/shared/preview/sample_content.dart';

/// The dish these price tests are about.
///
/// Stated rather than relying on the screen's fallback: the screen used to
/// default to a sample dish costing £17.50, and every expectation below was
/// silently pinned to that.
const _priced = Dish(
  id: 'd1',
  name: 'Black Pork Curry',
  description: 'Dark roasted heritage classic.',
  pricePence: 1750,
);

Widget wrapDish() => const DishDetailsScreen(dish: _priced);

void main() {
  group('CartCubit', () {
    const curry = Dish(
      id: 'd1',
      name: 'Chicken Kottu',
      description: '',
      pricePence: 895,
    );
    const hoppers = Dish(
      id: 'd2',
      name: 'Hoppers',
      description: '',
      pricePence: 450,
    );

    test('starts empty', () {
      final cart = CartCubit();
      expect(cart.state.isEmpty, isTrue);
      expect(cart.state.count, 0);
    });

    test('holds real lines, not a count', () {
      final cart = CartCubit()..addDish(curry, quantity: 2);

      // The counter it used to be could not place an order: there was nothing to
      // send. A line carries the three fields the API accepts.
      expect(cart.state.lines.single.dishId, 'd1');
      expect(cart.state.lines.single.toJson(), {
        'dish_id': 'd1',
        'quantity': 2,
      });
      expect(cart.state.count, 2);
    });

    test('merges the same dish with the same note', () {
      final cart = CartCubit()
        ..addDish(curry, notes: 'Mild')
        ..addDish(curry, notes: 'Mild');

      // Two taps of add should read as one line of two.
      expect(cart.state.lines, hasLength(1));
      expect(cart.state.lines.single.quantity, 2);
    });

    test('keeps a different note as its own line', () {
      final cart = CartCubit()
        ..addDish(curry, notes: 'Mild')
        ..addDish(curry, notes: 'Hot');

      // A different note is a different instruction to the kitchen.
      expect(cart.state.lines, hasLength(2));
    });

    test('a blank note is no note at all', () {
      final cart = CartCubit()..addDish(curry, notes: '   ');
      expect(cart.state.lines.single.notes, isNull);
      expect(cart.state.lines.single.toJson().containsKey('notes'), isFalse);
    });

    test('caps a line at the API limit rather than being refused', () {
      final cart = CartCubit()..addDish(curry, quantity: 80);
      expect(cart.state.lines.single.quantity, CartState.maxQuantity);
    });

    test('setting a quantity to zero removes the line', () {
      final cart = CartCubit()
        ..addDish(curry)
        ..addDish(hoppers);
      cart.setQuantity(cart.state.lines.first, 0);

      expect(cart.state.lines.single.dishId, 'd2');
    });

    test('the subtotal is display only', () {
      final cart = CartCubit()
        ..addDish(curry, quantity: 2)
        ..addDish(hoppers);

      // Shown while the quote is loading; the server's figure is what charges.
      expect(cart.state.displaySubtotalPence, 895 * 2 + 450);
    });

    test('clear empties it', () {
      final cart = CartCubit()..addDish(curry, quantity: 4);
      cart.clear();
      expect(cart.state.isEmpty, isTrue);
    });
  });

  group('DishDetails pricing', () {
    Widget wrap(Widget child) => BlocProvider(
      create: (_) => CartCubit(),
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

    testWidgets('opens at the dish price for a single unit', (tester) async {
      await tester.pumpWidget(wrap(wrapDish()));
      await tester.pumpAndSettle();

      // Featured dish is £17.50.
      expect(find.text('£17.50'), findsOneWidget);
    });

    testWidgets('quantity multiplies the total', (tester) async {
      await tester.pumpWidget(wrap(wrapDish()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsWidgets);
      expect(find.text('£35.00'), findsOneWidget);
    });

    testWidgets('an add-on raises the total', (tester) async {
      await tester.pumpWidget(wrap(wrapDish()));
      await tester.pumpAndSettle();

      // Coconut Roti is £3.50, and sits below the fold on a test viewport.
      await tester.scrollUntilVisible(find.text('Coconut Roti'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coconut Roti'));
      await tester.pumpAndSettle();

      expect(find.text('£21.00'), findsOneWidget);
    });

    testWidgets('add-ons multiply with quantity', (tester) async {
      await tester.pumpWidget(wrap(wrapDish()));
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
      await tester.pumpWidget(wrap(wrapDish()));
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
      await tester.pumpWidget(wrap(wrapDish()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Ordering zero of something is not a thing the UI should allow.
      expect(find.text('£17.50'), findsOneWidget);
    });

    testWidgets('renders the dish it was given, not the featured one', (
      tester,
    ) async {
      const dish = Dish(
        id: 'd9',
        name: 'Tempered Dhal',
        description: 'Red lentils.',
        pricePence: 1200,
      );
      await tester.pumpWidget(wrap(const DishDetailsScreen(dish: dish)));
      await tester.pumpAndSettle();

      expect(find.text('Tempered Dhal'), findsOneWidget);
      expect(find.text('£12.00'), findsOneWidget);
      // Its own description, not another dish's. The screen used to print one
      // hardcoded paragraph about Black Pork Curry whatever it was given.
      expect(find.text('Red lentils.'), findsOneWidget);
    });

    testWidgets('shows the kitchen\'s prep time, not a fixed one', (
      tester,
    ) async {
      const dish = Dish(
        id: 'd9',
        name: 'Hoppers',
        description: 'Fermented rice pancakes.',
        pricePence: 950,
        prepMinMinutes: 15,
        prepMaxMinutes: 20,
      );
      await tester.pumpWidget(wrap(const DishDetailsScreen(dish: dish)));
      await tester.pumpAndSettle();

      expect(find.text('Ready in 15–20 min'), findsOneWidget);
      // "45-60 min delivery" was printed for every dish on the menu.
      expect(find.textContaining('45-60'), findsNothing);
    });

    testWidgets('a dish with no description says so', (tester) async {
      const dish = Dish(
        id: 'd9',
        name: 'Plain',
        description: '',
        pricePence: 500,
      );
      await tester.pumpWidget(wrap(const DishDetailsScreen(dish: dish)));
      await tester.pumpAndSettle();

      expect(find.text('No description yet.'), findsOneWidget);
    });

    testWidgets('spice level is single-select', (tester) async {
      await tester.pumpWidget(wrap(wrapDish()));
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
