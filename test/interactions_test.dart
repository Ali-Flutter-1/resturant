import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/presentation/admin_menu_management_screen.dart';
import 'package:practice/features/admin/presentation/admin_orders_screen.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/menu/presentation/menu_screen.dart';

/// Controls that used to be dead. Each test asserts the thing the button
/// actually does, so a future refactor cannot quietly return it to a no-op.
void main() {
  Widget wrap(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AuthCubit()..signInAs(UserRole.customer)),
      BlocProvider(create: (_) => CartCubit()),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  );

  group('menu search and filters', () {
    testWidgets('typing narrows the list', (tester) async {
      await tester.pumpWidget(wrap(const MenuScreen()));
      await tester.pumpAndSettle();

      // Only the first card or two are built at this viewport — a lazy
      // ListView never constructs the rest — so the assertion works on what
      // filtering brings *to the top*.
      expect(find.text('Jaffna Crab Curry'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'dhal');
      await tester.pumpAndSettle();

      expect(find.text('Tempered Dhal'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });

    testWidgets('a search with no matches explains itself', (tester) async {
      await tester.pumpWidget(wrap(const MenuScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sushi');
      await tester.pumpAndSettle();

      expect(find.text('No dishes match'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('clearing filters restores the full menu', (tester) async {
      await tester.pumpWidget(wrap(const MenuScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sushi');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Curry'), findsOneWidget);
      expect(find.text('No dishes match'), findsNothing);
    });

    testWidgets('the Vegan filter keeps only vegan dishes', (tester) async {
      await tester.pumpWidget(wrap(const MenuScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vegan'));
      await tester.pumpAndSettle();

      expect(find.text('Young Jackfruit Curry'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });

    testWidgets('an initial query arrives pre-applied', (tester) async {
      await tester.pumpWidget(wrap(const MenuScreen(initialQuery: 'dhal')));
      await tester.pumpAndSettle();

      expect(find.text('Tempered Dhal'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });
  });

  group('admin orders', () {
    testWidgets('tapping an order offers its next states', (tester) async {
      await tester.pumpWidget(wrap(const AdminOrdersScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Table 4'));
      await tester.pumpAndSettle();

      expect(find.text('Order #042'), findsOneWidget);
      // A preparing order can become ready or overdue — never served
      // directly, and never back to preparing. Scoped to the sheet, since
      // the filter chips behind it carry the same words.
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Ready')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Served')),
        findsNothing,
      );
    });

    testWidgets('choosing a state updates the row', (tester) async {
      await tester.pumpWidget(wrap(const AdminOrdersScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Table 4'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Ready'),
        ),
      );
      await tester.pumpAndSettle();

      // #042 started as Preparing; two rows should now read READY.
      expect(find.text('READY'), findsNWidgets(2));
    });
  });

  group('admin menu management', () {
    testWidgets('Add opens an editor and rejects an empty dish', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Add a dish'), findsOneWidget);

      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();
      expect(find.text('Give the dish a name.'), findsOneWidget);
    });

    testWidgets('a valid dish is added to the menu', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      expect(find.text('4 of 5 dishes available tonight.'), findsNothing);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Watalappan');
      await tester.enterText(find.byType(TextField).at(2), '6.50');
      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      expect(find.text('Watalappan'), findsOneWidget);
    });

    testWidgets('a bad price is rejected', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Watalappan');
      await tester.enterText(find.byType(TextField).at(2), 'free');
      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a price, like 12.50.'), findsOneWidget);
    });
  });
}
