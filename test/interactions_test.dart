import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/network/api_failure.dart';
import 'package:practice/shared/widgets/dish_list_skeleton.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/widgets/app_chip.dart';
import 'package:practice/features/admin/presentation/admin_menu_management_screen.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/admin/domain/admin_menu_repository.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/features/menu/domain/menu_repository.dart';
import 'package:practice/features/menu/presentation/menu_screen.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_admin_menu_repository.dart';
import 'support/fake_menu_repository.dart';

/// Controls that used to be dead. Each test asserts the thing the button
/// actually does, so a future refactor cannot quietly return it to a no-op.
/// The editor's input carrying [hint], regardless of what else on screen
/// happens to be a text field.
Finder _field(String hint) =>
    find.ancestor(of: find.text(hint), matching: find.byType(TextField));

/// The availability switch on the row for [name].

void main() {
  Widget wrap(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.customer)),
      BlocProvider(create: (_) => CartCubit()),
    ],
    child: RepositoryProvider<MenuRepository>(
      create: (_) => FakeMenuRepository(),
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );

  group('menu', () {
    /// The menu screen with a repository of its own, so a test can choose what
    /// the server says.
    Widget menu({FakeMenuRepository? repository, String? initialQuery}) =>
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AuthFixtures.cubit(AuthFixtures.customer),
            ),
            BlocProvider(create: (_) => CartCubit()),
          ],
          child: RepositoryProvider<MenuRepository>(
            create: (_) => repository ?? FakeMenuRepository(),
            child: MaterialApp(
              theme: AppTheme.light,
              home: MenuScreen(initialQuery: initialQuery),
            ),
          ),
        );

    testWidgets('shows a skeleton while loading, then the dishes', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          repository: FakeMenuRepository(
            delay: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump();

      // Shaped like the real cards, so nothing reflows when the data lands.
      expect(find.byType(DishListSkeleton), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byType(DishListSkeleton), findsNothing);
      expect(find.text('Jaffna Crab Curry'), findsOneWidget);
    });

    testWidgets('a failure shows the API\'s message and can be retried', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          repository: FakeMenuRepository(
            failure: const ApiFailure(
              kind: ApiFailureKind.unreachable,
              message: "We couldn't reach the restaurant's server.",
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't reach the restaurant's server."),
        findsOneWidget,
      );
      // Unreachable is worth another go, so the button is offered.
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a refusal that retrying cannot fix offers no retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(
          repository: FakeMenuRepository(
            failure: const ApiFailure(
              kind: ApiFailureKind.notFound,
              message: "We couldn't find that.",
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("We couldn't find that."), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an empty menu says so, rather than looking broken', (
      tester,
    ) async {
      await tester.pumpWidget(
        menu(repository: FakeMenuRepository(dishes: const [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('The menu is being updated'), findsOneWidget);
    });

    testWidgets('typing narrows the list', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Curry'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'hoppers');
      await tester.pumpAndSettle();

      expect(find.text('Heritage Hoppers'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });

    testWidgets('a search with no matches explains itself', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sushi');
      await tester.pumpAndSettle();

      // Different words from an empty menu: a filter excluding everything is
      // the user's doing and is undoable.
      expect(find.text('No dishes match'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('clearing filters restores the full menu', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'sushi');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Curry'), findsOneWidget);
      expect(find.text('No dishes match'), findsNothing);
    });

    testWidgets('the category chips come from the API', (tester) async {
      await tester.pumpWidget(menu());
      await tester.pumpAndSettle();

      // Scoped to the filter chips: a dish card now carries its own section
      // name too, so an unscoped finder matches once per card as well.
      expect(find.widgetWithText(SelectableChip, 'All'), findsOneWidget);
      expect(
        find.widgetWithText(SelectableChip, 'Curry Dishes'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SelectableChip, 'Small Plates'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(SelectableChip, 'Small Plates'));
      await tester.pumpAndSettle();

      expect(find.text('Heritage Hoppers'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });

    testWidgets('a sold-out dish is listed but cannot be opened', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AuthFixtures.cubit(AuthFixtures.customer),
            ),
            BlocProvider(create: (_) => CartCubit()),
          ],
          child: RepositoryProvider<MenuRepository>(
            create: (_) =>
                FakeMenuRepository(dishes: const [FakeMenuRepository.soldOut]),
            child: MaterialApp(
              theme: AppTheme.light,
              home: MenuScreen(onOpenDish: (_) => opened++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Still on the menu — the API keeps listing it so the menu doesn't
      // appear to shrink through the evening.
      expect(find.text('Black Pork Curry'), findsOneWidget);
      expect(find.text('Not available'), findsWidgets);

      await tester.tap(find.text('Black Pork Curry'));
      await tester.pumpAndSettle();
      expect(opened, 0, reason: 'a sold-out dish must not open');
    });

    testWidgets('an initial query arrives pre-applied', (tester) async {
      await tester.pumpWidget(menu(initialQuery: 'hoppers'));
      await tester.pumpAndSettle();

      expect(find.text('Heritage Hoppers'), findsOneWidget);
      expect(find.text('Jaffna Crab Curry'), findsNothing);
    });
  });

  group('admin menu management', () {
    late FakeAdminMenuRepository admin;

    setUp(() {
      admin = FakeAdminMenuRepository();
      // Two dishes to start with, seeded rather than created through the editor
      // so a test about the list is not also a test about saving.
      admin
        ..seed(
          const Dish(
            id: 'd1',
            name: 'Jaffna Crab Curry',
            description: 'Fresh mud crab in roasted spices.',
            pricePence: 2800,
            categories: [FakeAdminMenuRepository.curries],
          ),
        )
        ..seed(
          const Dish(
            id: 'd2',
            name: 'Tempered Dhal',
            description: 'Red lentils with turmeric and curry leaves.',
            pricePence: 1200,
            categories: [FakeAdminMenuRepository.vegan],
            isAvailable: false,
          ),
        );
    });

    Widget wrapAdmin() => RepositoryProvider<AdminMenuRepository>.value(
      value: admin,
      child: wrap(const AdminMenuManagementScreen()),
    );

    testWidgets('loads the menu from the API', (tester) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      expect(find.text('Jaffna Crab Curry'), findsOneWidget);
      // One of the two is off tonight, and the count says so.
      expect(find.text('1 of 2 dishes available tonight.'), findsOneWidget);
    });

    testWidgets('the add button opens an editor and rejects an empty dish', (
      tester,
    ) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add a dish'), findsOneWidget);

      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();
      expect(find.text('Give the dish a name.'), findsOneWidget);
      expect(admin.lastCreate, isNull);
    });

    testWidgets('a saved dish is created through the API and listed', (
      tester,
    ) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(_field('Jaffna Crab Curry'), 'Watalappan');
      await tester.enterText(_field('12.50'), '6.50');

      // Scoped to the sheet: the same category names are chips on the screen
      // behind it, so an unscoped finder matches two widgets.
      final chip = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Vegan'),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add dish'));
      await tester.tap(find.text('Add dish'));
      await tester.pumpAndSettle();

      expect(admin.lastCreate?['title'], 'Watalappan');
      expect(admin.lastCreate?['price_pence'], 650);
      // Adopted into the list from the server's response rather than from the
      // form, so what the screen shows is what was actually saved.
      expect(find.text('2 of 3 dishes available tonight.'), findsOneWidget);
    });

    testWidgets('the availability switch PATCHes the dish', (tester) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsWidgets);
      final first = find.byType(Switch).first;
      final before = tester.widget<Switch>(first).value;

      await tester.tap(first);
      await tester.pumpAndSettle();

      expect(admin.lastUpdate?['id'], 'd1');
      expect(admin.lastUpdate?['is_available'], !before);
      expect(tester.widget<Switch>(first).value, !before);
    });

    testWidgets('a failed toggle leaves the switch where it was', (
      tester,
    ) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      admin.failure = const ApiFailure(
        kind: ApiFailureKind.server,
        message: 'Could not reach the kitchen system.',
      );

      final first = find.byType(Switch).first;
      final before = tester.widget<Switch>(first).value;
      await tester.tap(first);
      await tester.pumpAndSettle();

      // The state it would have shown was never true, so it must not stick.
      expect(tester.widget<Switch>(first).value, before);
      expect(find.text('Could not reach the kitchen system.'), findsOneWidget);
    });

    testWidgets('deleting confirms first, then calls the API', (tester) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      const doomed = 'Jaffna Crab Curry';
      expect(find.text(doomed), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();

      // Destructive, so it confirms — and backing out changes nothing.
      expect(find.text('Delete $doomed?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.text(doomed), findsOneWidget);
      expect(admin.deletedIds, isEmpty);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(admin.deletedIds, ['d1']);
      expect(find.text(doomed), findsNothing);
    });

    testWidgets('the delete dialog does not promise an undo', (tester) async {
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete dish'));
      await tester.pumpAndSettle();

      // The API has no restore route for dishes, so an "Undo" that could not
      // deliver would be worse than none. It used to offer one.
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('shows the API message when the menu will not load', (
      tester,
    ) async {
      admin.failure = ApiFailure.offline;
      await tester.pumpWidget(wrapAdmin());
      await tester.pumpAndSettle();

      expect(find.text(ApiFailure.offline.message), findsOneWidget);
    });
  });
}
