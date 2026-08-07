import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/animations/collapse.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/presentation/admin_menu_management_screen.dart';
import 'package:practice/features/admin/presentation/admin_orders_screen.dart';
import 'package:practice/features/auth/auth_cubit.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/menu/presentation/menu_screen.dart';

/// Controls that used to be dead. Each test asserts the thing the button
/// actually does, so a future refactor cannot quietly return it to a no-op.
/// The editor's input carrying [hint], regardless of what else on screen
/// happens to be a text field.
Finder _field(String hint) =>
    find.ancestor(of: find.text(hint), matching: find.byType(TextField));

/// The availability switch on the row for [name].
Switch _switchFor(WidgetTester tester, String name) {
  final card = find.ancestor(
    of: find.text(name),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<Switch>(
    find.descendant(of: card, matching: find.byType(Switch)),
  );
}

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

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Order #042'),
        ),
        findsOneWidget,
      );
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

      // Scoped to #042's own card. A global count would depend on how many
      // cards happen to be built, and the design's cards are tall enough that
      // the answer changes with the viewport.
      final card = find.ancestor(
        of: find.text('Table 4'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: card.evaluate().isEmpty ? find.byType(Scaffold) : card,
          matching: find.text('READY'),
        ),
        findsWidgets,
      );
      // And #042 is no longer preparing.
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.text('PREPARING'),
        ),
        findsOneWidget,
      );
    });
  });

  group('admin menu management', () {
    testWidgets('Add opens an editor and rejects an empty dish', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      // The design replaces the header "Add" button with a floating action
      // button, so the editor is opened from there now.
      await tester.tap(find.byType(FloatingActionButton));
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

      // The design replaces the header "Add" button with a floating action
      // button, so the editor is opened from there now.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Jaffna Crab Curry'), 'Watalappan');
      await tester.enterText(_field('12.50'), '6.50');
      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      // The count updates immediately; the row itself is appended below the
      // fold, so scroll the list rather than assuming it was built.
      expect(find.text('4 of 5 dishes available tonight.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Watalappan'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('Watalappan'), findsOneWidget);
    });

    testWidgets('a dish can be given a tag and a photograph', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Jaffna Crab Curry'), 'Watalappan');
      await tester.enterText(_field('12.50'), '6.50');

      // Scoped to the sheet: "Vegan" is also a category chip on the screen
      // behind it, so an unscoped finder matches two widgets.
      final veganChip = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Vegan'),
      );
      await tester.ensureVisible(veganChip);
      await tester.tap(veganChip);
      await tester.pumpAndSettle();

      await tester.enterText(
        _field('https://…/dish.jpg'),
        'https://example.com/watalappan.jpg',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      // The tag rides along to the row, which is how it shows on the card.
      await tester.scrollUntilVisible(
        find.text('Watalappan'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Scaffold),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('Watalappan'), findsOneWidget);
      expect(find.text('Vegan'), findsWidgets);
    });

    testWidgets('availability is a switch on the row', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      // One switch per visible dish, not an item buried in an overflow menu.
      expect(find.byType(Switch), findsWidgets);

      final first = find.byType(Switch).first;
      final before = tester.widget<Switch>(first).value;
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(first).value, !before);
    });

    testWidgets('a dish can be deleted, and the delete undone', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      const doomed = 'Jaffna Crab Curry';
      expect(find.text(doomed), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();

      // Destructive, so it confirms first — and backing out changes nothing.
      expect(find.text('Delete $doomed?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.text(doomed), findsOneWidget);

      // Now go through with it.
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text(doomed), findsNothing);

      // Undo puts it back.
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text(doomed), findsOneWidget);
    });

    testWidgets('deleting does not move availability onto another dish', (
      tester,
    ) async {
      // Tall enough that every row is built: the assertion is about which dish
      // holds the flag, and an unbuilt row can't be inspected.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      // "Tempered Dhal" starts off the menu. Availability used to be keyed by
      // list position, so deleting a dish above it would have shifted the
      // unavailable flag onto a different dish entirely.
      expect(_switchFor(tester, 'Tempered Dhal').value, isFalse);
      expect(_switchFor(tester, 'Jaffna Crab Curry').value, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Curry'), findsNothing);
      expect(_switchFor(tester, 'Tempered Dhal').value, isFalse);
    });

    testWidgets('an edit is applied, not just announced', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit dish'));
      await tester.pumpAndSettle();

      await tester.enterText(
        _field('Jaffna Crab Curry'),
        'Jaffna Crab Special',
      );
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Special'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });

    testWidgets('a deleted row folds shut instead of vanishing', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      const doomed = 'Jaffna Crab Curry';
      Finder foldFor(String name) =>
          find.ancestor(of: find.text(name), matching: find.byType(Collapse));
      final fullHeight = tester.getSize(foldFor(doomed)).height;
      expect(fullHeight, greaterThan(0));

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));

      // Mid-fold the row still exists, at reduced height — this is the frame
      // that used to be a jump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.getSize(foldFor(doomed)).height;
      expect(mid, lessThan(fullHeight));
      expect(mid, greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.text(doomed), findsNothing);
    });

    testWidgets('a bad price is rejected', (tester) async {
      await tester.pumpWidget(wrap(const AdminMenuManagementScreen()));
      await tester.pumpAndSettle();

      // The design replaces the header "Add" button with a floating action
      // button, so the editor is opened from there now.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Addressed by hint, not index: the screen behind the sheet has its own
      // search field, and positional finders silently target the wrong one.
      await tester.enterText(_field('Jaffna Crab Curry'), 'Watalappan');
      await tester.enterText(_field('12.50'), 'free');
      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a price, like 12.50.'), findsOneWidget);
    });
  });
}
