import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/presentation/dish_editor_sheet.dart';
import 'package:practice/features/menu/domain/dish.dart';

import 'support/fake_admin_menu_repository.dart';

/// The add-dish sheet.
///
/// Two things here are easy to regress and invisible in a diff: the order of the
/// form, and whether a category outside the built-in list can be entered at all.
void main() {
  late FakeAdminMenuRepository repository;
  Dish? saved;

  setUp(() {
    repository = FakeAdminMenuRepository();
    saved = null;
  });

  Future<void> open(WidgetTester tester, {Dish? dish}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await showDishEditor(
                context: context,
                repository: repository,
                categories: FakeAdminMenuRepository.defaultCategories,
                dish: dish,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the photograph comes before the name', (tester) async {
    await open(tester);

    final photograph = tester.getTopLeft(find.text('Photograph')).dy;
    final name = tester.getTopLeft(find.text('Name')).dy;
    final price = tester.getTopLeft(find.text('Price')).dy;

    // It was last. The most visible thing about a dish should not be the final
    // thing you are asked for, below the fold behind the keyboard.
    expect(photograph, lessThan(name));
    expect(name, lessThan(price));
  });

  testWidgets('offers both the camera and the gallery', (tester) async {
    await open(tester);

    expect(find.text('Camera'), findsOne);
    expect(find.text('Gallery'), findsOne);
    // No paste-a-URL field: the API takes `{public_id, url}` pairs from its own
    // upload endpoint, and a pasted link has no public_id — it could never be
    // saved, so offering the field would be offering a dead end.
    expect(find.textContaining('paste an image URL'), findsNothing);
  });

  testWidgets('a category outside the built-in list can be added', (
    tester,
  ) async {
    await open(tester);

    const custom = 'Street Food';
    expect(find.textContaining(custom), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Add another category'),
      custom,
    );
    await tester.ensureVisible(find.byTooltip('Add category'));
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    // Added *and* selected: typing a category is a statement that this dish is
    // in it, so making the user tap the new chip as well would be a second step
    // for no decision.
    // Marked "(new)" because it does not exist server-side yet — it is created
    // on save, so abandoning the sheet leaves no stray category behind.
    expect(find.text('$custom (new)'), findsOne);
  });

  testWidgets('creates the category first, then the dish with its id', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Kottu Roti',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '9.00');
    await tester.enterText(
      find.widgetWithText(TextField, 'Add another category'),
      'Street Food',
    );
    await tester.ensureVisible(find.byTooltip('Add category'));
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    // The category had to exist before the dish could reference it — the API
    // takes ids, not names.
    expect(repository.createdCategories, ['Street Food']);
    expect(repository.lastCreate?['category_ids'], contains('cat-new-3'));
    expect(repository.lastCreate?['title'], 'Kottu Roti');
    // Pence as an integer, and rounded: 9.00 × 100 in binary floating point is
    // not exactly 900, and truncating would sell it for £8.99.
    expect(repository.lastCreate?['price_pence'], 900);
    expect(saved?.name, 'Kottu Roti');
  });

  testWidgets('sends the prep-time range the API requires', (tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Hoppers',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '6.50');
    await tester.ensureVisible(find.text('Curry Dishes'));
    await tester.tap(find.text('Curry Dishes'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    // Defaulted rather than left null, because the API requires both.
    expect(repository.lastCreate?['prep_min'], 15);
    expect(repository.lastCreate?['prep_max'], 20);
  });

  testWidgets('refuses a prep range that runs backwards', (tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Hoppers',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '6.50');
    await tester.enterText(find.widgetWithText(TextField, '15'), '30');
    await tester.enterText(find.widgetWithText(TextField, '20'), '10');
    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    expect(
      find.text('The shortest time cannot be longer than the longest.'),
      findsOne,
    );
    expect(repository.lastCreate, isNull);
  });

  testWidgets('refuses a dish with no category', (tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Hoppers',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '6.50');
    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    // The API requires one, and an uncategorised dish would not appear on the
    // public menu even if it accepted one.
    expect(find.text('Choose at least one category.'), findsOne);
    expect(repository.lastCreate, isNull);
  });

  testWidgets('a dish can sit in several categories at once', (tester) async {
    await open(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Jackfruit Curry',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '18.00');
    await tester.ensureVisible(find.text('Curry Dishes'));
    await tester.tap(find.text('Curry Dishes'));
    await tester.ensureVisible(find.text('Vegan'));
    await tester.tap(find.text('Vegan'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    expect(
      repository.lastCreate?['category_ids'],
      containsAll(<String>['cat-1', 'cat-2']),
    );
  });

  testWidgets('reports the API message when saving fails', (tester) async {
    await open(tester);
    repository.failure = const ApiFailure(
      kind: ApiFailureKind.conflict,
      message: 'A dish with that name already exists.',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Hoppers',
    );
    await tester.enterText(find.widgetWithText(TextField, '12.50'), '6.50');
    await tester.ensureVisible(find.text('Curry Dishes'));
    await tester.tap(find.text('Curry Dishes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();

    // The API's own words, shown verbatim, and the sheet stays open so the
    // typing is not lost.
    expect(find.text('A dish with that name already exists.'), findsOne);
    expect(saved, isNull);
  });

  testWidgets('will not add the same category twice under a different case', (
    tester,
  ) async {
    await open(tester);

    final before = find.text('Vegan').evaluate().length;

    await tester.enterText(
      find.widgetWithText(TextField, 'Add another category'),
      'vegan',
    );
    await tester.ensureVisible(find.byTooltip('Add category'));
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    // Otherwise "vegan" becomes a second Vegan sitting beside the first, and no
    // category should be created for it on save either.
    expect(find.text('Vegan').evaluate().length, before);
    expect(find.text('vegan (new)'), findsNothing);
  });

  testWidgets(
    'an empty category is ignored rather than added as a blank chip',
    (tester) async {
      await open(tester);
      final before = find.byType(TextField).evaluate().length;

      await tester.ensureVisible(find.byTooltip('Add category'));
      await tester.tap(find.byTooltip('Add category'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField).evaluate().length, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('still refuses a dish with no name or a bad price', (
    tester,
  ) async {
    await open(tester);

    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();
    expect(find.text('Give the dish a name.'), findsOne);

    await tester.enterText(
      find.widgetWithText(TextField, 'Jaffna Crab Curry'),
      'Hoppers',
    );
    await tester.ensureVisible(find.text('Add dish'));
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a price, like 12.50.'), findsOne);
  });

  group('a section\'s logo', () {
    test('uploading returns the server\'s own image_url', () async {
      final repository = FakeAdminMenuRepository();
      final categories = await repository.categories();
      final target = categories.first;

      final updated = await repository.setCategoryLogo(target.id, '/tmp/a.jpg');

      expect(repository.logoChanges.last, {
        'id': target.id,
        'path': '/tmp/a.jpg',
      });
      // Displayed as sent. The guide is explicit that the app must never build
      // a Cloudinary URL of its own.
      expect(updated.imageUrl, isNotNull);
      expect(updated.imageUrl, startsWith('https://'));
      expect(updated.id, target.id);
      expect(updated.name, target.name);
    });

    test('removing clears the picture and keeps the section', () async {
      final repository = FakeAdminMenuRepository();
      final target = (await repository.categories()).first;
      await repository.setCategoryLogo(target.id, '/tmp/a.jpg');

      final cleared = await repository.removeCategoryLogo(target.id);

      expect(cleared.imageUrl, isNull);
      expect(cleared.name, target.name);
      // The whole category comes back, not a bare acknowledgement, so the
      // caller re-renders from one source.
      expect((await repository.categories()).first.imageUrl, isNull);
    });
  });
}
