import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/shared/animations/fly_to_cart.dart';
import 'package:practice/shared/widgets/cart_icon_button.dart';

/// The contract the spec sets out: the original stays put, a copy flies, the
/// UI keeps taking input while it does, the count changes on arrival, and
/// nothing is left behind afterwards.
void main() {
  late GlobalKey sourceKey;
  late GlobalKey cartKey;
  late CartCubit cart;
  int taps = 0;

  Widget harness({bool reduceMotion = false}) {
    sourceKey = GlobalKey();
    cartKey = GlobalKey();
    cart = CartCubit();
    taps = 0;

    return BlocProvider.value(
      value: cart,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              appBar: AppBar(actions: [CartIconButton(targetKey: cartKey)]),
              body: Column(
                children: [
                  Container(
                    key: sourceKey,
                    width: 120,
                    height: 120,
                    color: Colors.red,
                  ),
                  Builder(
                    builder: (innerContext) => ElevatedButton(
                      onPressed: () => FlyToCart.launch(
                        context: innerContext,
                        sourceKey: sourceKey,
                        targetKey: cartKey,
                        child: const ColoredBox(color: Colors.red),
                        // The flight's only job is to land; what it lands *is*
                        // decided by the screen that launched it.
                        onArrive: () => cart.addDish(
                          const Dish(
                            id: 'd1',
                            name: 'Kottu',
                            description: '',
                            pricePence: 895,
                          ),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                  // Proves the app stays interactive mid-flight.
                  ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Other'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the original stays put while a copy flies', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final before = tester.getTopLeft(find.byKey(sourceKey));

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getTopLeft(find.byKey(sourceKey)),
      before,
      reason: 'the source image must not move — only a copy travels',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('the UI stays interactive during the flight', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Mid-flight: the overlay must not swallow this.
    await tester.tap(find.text('Other'));
    await tester.pump();

    expect(taps, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('the count rises only once the copy lands', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      cart.state.count,
      0,
      reason: 'the badge must not update before the item arrives',
    );

    await tester.pumpAndSettle();
    expect(cart.state.count, 1);
  });

  testWidgets('the overlay is torn down when the flight ends', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final before = tester.widgetList(find.byType(IgnorePointer)).length;

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      tester.widgetList(find.byType(IgnorePointer)).length,
      before,
      reason: 'the flying copy must be removed, not merely hidden',
    );
  });

  testWidgets('reduce-motion skips the flight but still adds the item', (
    tester,
  ) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pump();

    expect(
      cart.state.count,
      1,
      reason: 'the outcome must not depend on the animation running',
    );
  });

  testWidgets('the badge appears and counts up', (tester) async {
    await tester.pumpWidget(harness(reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
}
