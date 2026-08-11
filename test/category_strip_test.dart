import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/discover/presentation/discover_screen.dart';
import 'package:practice/features/menu/domain/dish.dart';
import 'package:practice/features/menu/domain/menu_repository.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_menu_repository.dart';

/// The home screen's category circles.
///
/// They used to be five hardcoded labels — Breakfast, Curry, Kottu, Sides,
/// Drinks — invented for the design and unrelated to what the kitchen serves,
/// and tapping one only moved a highlight. Both are what these pin.
void main() {
  Widget wrap(FakeMenuRepository repository, {ValueChanged<String>? onTap}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.customer)),
        BlocProvider(create: (_) => CartCubit()),
      ],
      child: RepositoryProvider<MenuRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: DiscoverScreen(onOpenCategory: onTap),
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
    expect(find.text(ApiFailure.offline.message), findsNothing);
    // The rest of the screen still works.
    expect(find.text('Popular Now'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides itself when there are no sections yet', (tester) async {
    await tester.pumpWidget(
      wrap(FakeMenuRepository(categories: const [], dishes: const [])),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Popular Now'), findsOne);
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
}
