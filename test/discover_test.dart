import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/discover/presentation/discover_screen.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/features/discover/presentation/discover_cubit.dart';
import 'package:practice/features/menu/domain/menu_repository.dart';
import 'package:practice/shared/widgets/dish_image.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_menu_repository.dart';

/// The home screen's category circles.
///
/// They used to be five hardcoded labels — Breakfast, Curry, Kottu, Sides,
/// Drinks — invented for the design and unrelated to what the kitchen serves,
/// and tapping one only moved a highlight. Both are what these pin.
void main() {
  Widget wrap(
    FakeMenuRepository repository, {
    ValueChanged<String>? onTap,
    ValueChanged<Dish>? onOpenDish,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.customer)),
        BlocProvider(create: (_) => CartCubit()),
      ],
      child: RepositoryProvider<MenuRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: DiscoverScreen(onOpenCategory: onTap, onOpenDish: onOpenDish),
        ),
      ),
    );
  }

  testWidgets('shows the sections the API returns', (tester) async {
    await tester.pumpWidget(wrap(FakeMenuRepository()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Curry Dishes'), findsWidgets);
    expect(find.text('Small Plates'), findsWidgets);
    // The invented labels are gone: an admin's own categories are the only
    // thing that appears here now.
    expect(find.text('Kottu'), findsNothing);
    expect(find.text('Drinks'), findsNothing);
  });

  testWidgets('tapping one opens the menu filtered to its slug', (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(wrap(FakeMenuRepository(), onTap: tapped.add));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Curry Dishes').first);
    await tester.pumpAndSettle();

    // The slug, because that is what the menu filters on.
    expect(tapped, ['curry-dishes']);
  });

  testWidgets('hides itself when the sections will not load', (tester) async {
    await tester.pumpWidget(
      wrap(FakeMenuRepository(failure: ApiFailure.offline)),
    );
    await tester.pump(const Duration(seconds: 2));

    // Hidden, not an error panel: the strip is one way into the menu among
    // several, and an error across the top of the home screen would be louder
    // than the problem.
    expect(find.text('Curry Dishes'), findsNothing);
    // The rest of the screen still works — and the dishes half reports the
    // failure inline rather than the whole screen being replaced.
    expect(find.byType(TextField), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides itself when there are no sections yet', (tester) async {
    await tester.pumpWidget(
      wrap(FakeMenuRepository(categories: const [], dishes: const [])),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to a glyph for a section with no picture', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        FakeMenuRepository(
          categories: const [
            MenuCategory(id: 'c1', slug: 'breakfast', name: 'Breakfast'),
            MenuCategory(id: 'c2', slug: 'drinks', name: 'Drinks'),
            MenuCategory(id: 'c3', slug: 'other', name: 'Something Else'),
          ],
          dishes: const [],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Matched from the name, since the API carries no icon.
    expect(find.byIcon(Icons.egg_alt_outlined), findsOne);
    expect(find.byIcon(Icons.local_cafe_outlined), findsOne);
    // An unrecognised name still gets something rather than an empty ring.
    expect(find.byIcon(Icons.restaurant_menu), findsOne);
  });

  group('menu highlights', () {
    testWidgets('shows a hero card and a strip of the rest', (tester) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      // Only the first hero is built — the rest are pages of a pager — and the
      // strip holds whatever the heroes did not take.
      expect(find.text('Jaffna Crab Curry'), findsOne);
      expect(find.text('On the menu'), findsOne);
      expect(find.text('See All'), findsOne);
    });

    testWidgets('the latest dishes swipe sideways rather than stacking', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      // A pager, so a full-width card is never left half on screen — and the
      // later heroes are reachable without scrolling the page.
      expect(find.byType(PageView), findsOne);

      // Full width, so a card's edges land on the page gutter: the same line the
      // search bar above it sits on.
      final pager = tester.widget<PageView>(find.byType(PageView));
      expect(pager.controller?.viewportFraction, 1.0);
    });

    testWidgets('the hero card lines up with the search bar', (tester) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      final search = tester.getRect(find.byType(TextField));
      // The card, not the pager: the pager itself is deliberately full-bleed so
      // consecutive cards are a gutter apart, and each page pads itself back in.
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(PageView),
              matching: find.byType(DishImage),
            )
            .first,
      );

      expect(card.left, closeTo(search.left, 0.5));
      expect(card.right, closeTo(search.right, 0.5));
    });

    testWidgets('the image block is the same size with or without a photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FakeMenuRepository(
            // Enough that the heroes do not swallow them all: the comparison is
            // between cards in the strip.
            dishes: const [
              Dish(
                id: 'h1',
                name: 'Hero one',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 'h2',
                name: 'Hero two',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 'h3',
                name: 'Hero three',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 'with',
                name: 'With a photo',
                description: 'x',
                pricePence: 100,
                imageUrlOverride: 'https://example.com/a.jpg',
                categories: [FakeMenuRepository.curries],
              ),
              Dish(
                id: 'without',
                name: 'Without a photo',
                description: 'x',
                pricePence: 100,
                categories: [FakeMenuRepository.curries],
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Scoped to the *horizontal* list: the page itself is a ListView, so an
      // unscoped descendant search also picks up the hero card, which is
      // legitimately a different size.
      final strip = find
          .byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal,
          )
          .last;
      final images = find.descendant(
        of: strip,
        matching: find.byType(DishImage),
      );
      final sizes = tester
          .widgetList<DishImage>(images)
          .map((w) => tester.getSize(find.byWidget(w)))
          .toSet();
      expect(
        sizes,
        hasLength(1),
        reason: 'every card\'s image block should be identical in size',
      );
    });

    testWidgets('the strip scrolls horizontally', (tester) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      final strips = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      );
      // Two: the category circles and the dish cards. A vertical grid of two
      // cards is what this replaced.
      expect(strips, findsNWidgets(2));
    });

    testWidgets('a sold-out dish cannot be ordered from the card', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FakeMenuRepository(
            dishes: const [
              Dish(
                id: 'd9',
                name: 'Black Pork Curry',
                description: 'Sold out tonight.',
                pricePence: 2200,
                categories: [FakeMenuRepository.curries],
                isAvailable: false,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Still listed — the API keeps dishes an admin has turned off, so the menu
      // does not appear to shrink — but the button says so rather than opening a
      // dish nobody can order.
      expect(find.text('Not available'), findsWidgets);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Not available'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an empty menu says the kitchen has not published one', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(FakeMenuRepository(categories: const [], dishes: const [])),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('The menu is being prepared'), findsOne);
      expect(find.text('On the menu'), findsNothing);
    });

    testWidgets('a failed load reports it inline and offers a retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(FakeMenuRepository(failure: ApiFailure.offline)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(ApiFailure.offline.message), findsOne);
      expect(find.text('Try again'), findsOne);
      // The greeting and search above it are untouched.
      expect(find.byType(TextField), findsOne);
    });

    testWidgets('tapping a strip card opens that dish', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        wrap(
          FakeMenuRepository(
            dishes: const [
              Dish(
                id: 'h1',
                name: 'Hero one',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 'h2',
                name: 'Hero two',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 'h3',
                name: 'Hero three',
                description: 'x',
                pricePence: 100,
              ),
              Dish(
                id: 's1',
                name: 'In the strip',
                description: 'x',
                pricePence: 100,
              ),
            ],
          ),
          onOpenDish: (d) => opened.add(d.name),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      // Below the fold on the default test viewport, so scrolled to first: the
      // strip sits under the hero pager.
      await tester.scrollUntilVisible(
        find.text('In the strip'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('In the strip'));
      await tester.pumpAndSettle();

      expect(opened, ['In the strip']);
    });
  });

  group('DiscoverState', () {
    DiscoverState stateWith(List<Dish> dishes) =>
        DiscoverState(status: DiscoverStatus.ready, dishes: dishes);

    Dish dish(String id, {bool available = true, DateTime? created}) => Dish(
      id: id,
      name: 'Dish $id',
      description: '',
      pricePence: 100,
      isAvailable: available,
      createdAt: created,
    );

    test('the heroes are the newest dishes', () {
      final state = stateWith([
        dish('oldest', created: DateTime(2026, 1, 1)),
        dish('newest', created: DateTime(2026, 8, 10)),
        dish('middle', created: DateTime(2026, 5, 1)),
        dish('older', created: DateTime(2026, 2, 1)),
      ]);

      expect(state.heroes.map((d) => d.id), ['newest', 'middle', 'older']);
    });

    test('there are three of them', () {
      final many = [
        for (var i = 0; i < 9; i++)
          dish('d$i', created: DateTime(2026, 1, i + 1)),
      ];
      expect(stateWith(many).heroes, hasLength(DiscoverState.heroCount));
    });

    test('an unavailable dish does not take the most prominent place', () {
      final state = stateWith([
        dish(
          'newest-but-off',
          available: false,
          created: DateTime(2026, 8, 10),
        ),
        dish('older-but-on', created: DateTime(2026, 5, 1)),
      ]);

      // Newest first *within* what can be ordered: leading with something
      // nobody can buy wastes the largest card on the screen.
      expect(state.heroes.first.id, 'older-but-on');
    });

    test('a dish with no timestamp does not claim to be new', () {
      final state = stateWith([
        dish('undated'),
        dish('dated', created: DateTime(2026, 8, 10)),
      ]);
      expect(state.heroes.first.id, 'dated');
    });

    test('no dishes means no hero cards at all', () {
      expect(stateWith(const []).heroes, isEmpty);
    });

    test('the strip never repeats a hero', () {
      final state = stateWith([
        dish('a', created: DateTime(2026, 8, 4)),
        dish('b', created: DateTime(2026, 8, 3)),
        dish('c', created: DateTime(2026, 8, 2)),
        dish('d', created: DateTime(2026, 8, 1)),
      ]);

      expect(state.heroes.map((d) => d.id), ['a', 'b', 'c']);
      expect(state.strip.map((d) => d.id), ['d']);
    });

    test('the strip is capped, so the home screen stays a summary', () {
      final many = [
        for (var i = 0; i < 20; i++)
          dish('d$i', created: DateTime(2026, 1, 1).add(Duration(days: i))),
      ];
      expect(stateWith(many).strip, hasLength(DiscoverState.highlightCount));
    });

    test('unavailable dishes sink rather than being hidden', () {
      final state = stateWith([
        dish('off', available: false, created: DateTime(2026, 8, 6)),
        dish('on1', created: DateTime(2026, 8, 5)),
        dish('on2', created: DateTime(2026, 8, 4)),
        dish('on3', created: DateTime(2026, 8, 3)),
        dish('on4', created: DateTime(2026, 8, 2)),
      ]);

      // Hiding them while the full menu lists them would make the two screens
      // disagree — so the off one is last, not absent.
      expect(state.heroes.map((d) => d.id), ['on1', 'on2', 'on3']);
      expect(state.strip.map((d) => d.id), ['on4', 'off']);
    });
  });

  group('the greeting', () {
    testWidgets('names no city, and offers no fake location picker', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text("T's Lover"), findsOne);
      // It said "Colombo, LK" — the wrong country — behind a pin and a chevron
      // that looked like a picker and opened nothing.
      expect(find.text('Colombo, LK'), findsNothing);
      expect(find.byIcon(Icons.place), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('greets by the hour rather than always "Good Morning"', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(FakeMenuRepository()));
      await tester.pump(const Duration(seconds: 2));

      // Whichever it is where this runs, it is one of the three and it came from
      // the clock.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Good morning,' ||
                  w.data == 'Good afternoon,' ||
                  w.data == 'Good evening,'),
        ),
        findsOne,
      );
      expect(find.text('Good Morning,'), findsNothing);
    });
  });
}
