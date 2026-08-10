import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/animations/page_transitions.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/about/presentation/about_contact_screen.dart';
import 'package:practice/features/booking/presentation/book_table_screen.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/checkout/presentation/checkout_screen.dart';
import 'package:practice/features/discover/presentation/discover_screen.dart';
import 'package:practice/features/menu/presentation/dish_details_screen.dart';
import 'package:practice/features/menu/domain/menu_repository.dart';
import 'package:practice/features/menu/presentation/menu_screen.dart';
import 'package:practice/features/shell/admin_shell.dart';
import 'package:practice/shared/widgets/flutter_glass_nav_bar.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_menu_repository.dart';

/// Every screen needs a way out, and no screen may advertise one it doesn't
/// have. These tests pin both halves of that, because both have been wrong:
/// two tab roots shipped a permanently disabled back arrow, and the pushed
/// menu shipped with no back control at all.
Widget _host(Widget home, {TargetPlatform? platform}) {
  final theme = platform == null
      ? AppTheme.light
      : AppTheme.light.copyWith(platform: platform);
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.customer)),
      BlocProvider(create: (_) => CartCubit()),
    ],
    child: RepositoryProvider<MenuRepository>(
      // MenuScreen resolves its repository from the tree; these tests care
      // about navigation, not about what the menu contains.
      create: (_) => FakeMenuRepository(),
      child: MaterialApp(theme: theme, home: home),
    ),
  );
}

/// Pumps [screen] as a pushed route and returns once it has settled.
Future<void> _push(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(AppPageRoute<void>(builder: (_) => screen)),
          child: const Text('origin'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('origin'));
  await tester.pumpAndSettle();
}

void main() {
  group('tab roots', () {
    // Nothing sits behind a tab root, so a back control there could only ever
    // be inert.
    final roots = <String, Widget>{
      'Discover': const DiscoverScreen(),
      'BookTable': const BookTableScreen(),
      'AboutContact': const AboutContactScreen(),
    };

    for (final entry in roots.entries) {
      testWidgets('${entry.key} shows no back control', (tester) async {
        await tester.pumpWidget(_host(entry.value));
        await tester.pump(const Duration(seconds: 2));

        expect(
          find.byIcon(Icons.arrow_back),
          findsNothing,
          reason: '${entry.key} is a tab root and must not offer a way back',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('pushed screens', () {
    testWidgets('Menu offers a back control that pops', (tester) async {
      await _push(tester, const MenuScreen());

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('origin'), findsOneWidget);
    });

    testWidgets('DishDetails offers a back control that fires onBack', (
      tester,
    ) async {
      var backs = 0;
      await _push(tester, DishDetailsScreen(onBack: () => backs++));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('Checkout offers a back control that fires onBack', (
      tester,
    ) async {
      var backs = 0;
      await _push(tester, CheckoutScreen(onBack: () => backs++));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      expect(backs, 1);
    });
  });

  group('no screen ever shows a disabled back control', () {
    // The failure this guards against is subtle on screen but total in
    // effect: IconButton renders a greyed arrow for a null callback, so the
    // app appears to offer a way back and simply ignores the tap.
    final screens = <String, Widget>{
      'Discover': const DiscoverScreen(),
      'BookTable': const BookTableScreen(),
      'AboutContact': const AboutContactScreen(),
      'Menu': const MenuScreen(),
      'DishDetails': const DishDetailsScreen(),
      'Checkout': const CheckoutScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key}, unwired', (tester) async {
        await tester.pumpWidget(_host(entry.value));
        await tester.pump(const Duration(seconds: 2));

        for (final button in tester.widgetList<IconButton>(
          find.byType(IconButton),
        )) {
          expect(
            button.onPressed,
            isNotNull,
            reason: '${entry.key} renders an IconButton that does nothing',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('pushed without onBack', () {
    // These screens are always wired by CustomerShell today. Should that ever
    // lapse, the framework's implied BackButton must still get the user out.
    final screens = <String, Widget>{
      'DishDetails': const DishDetailsScreen(),
      'Checkout': const CheckoutScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key} still pops', (tester) async {
        await _push(tester, entry.value);
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('origin'), findsOneWidget);
      });
    }
  });

  group('platform back gesture', () {
    testWidgets('an edge swipe pops on iOS', (tester) async {
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(AppPageRoute<void>(builder: (_) => const Text('detail'))),
              child: const Text('origin'),
            ),
          ),
          platform: TargetPlatform.iOS,
        ),
      );

      await tester.tap(find.text('origin'));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      // Drag in from the left edge. This only works while the theme routes
      // Apple platforms through CupertinoPageTransitionsBuilder — the gesture
      // detector lives inside it, so substituting another transition silently
      // removes the gesture.
      await tester.dragFrom(const Offset(2, 300), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('detail'), findsNothing);
      expect(find.text('origin'), findsOneWidget);
    });
  });

  group('controls clear of the tab bar', () {
    testWidgets('the admin add-dish button is not hidden behind the bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.admin)),
            BlocProvider(create: (_) => CartCubit()),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AdminShell()),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Products'));
      await tester.pump(const Duration(seconds: 2));

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final bar = tester.getRect(find.byType(FlutterGlassNavBar));

      // The bar paints over the tab's content, so any overlap at all means the
      // button is invisible — and untappable — rather than merely cramped.
      expect(
        fab.bottom,
        lessThanOrEqualTo(bar.top),
        reason:
            'the add-dish FAB ($fab) is behind the tab bar ($bar); Scaffold '
            'anchors it to its own bottom edge, so it needs lifting by the '
            "shell's reported bottom padding",
      );

      // And it still works.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add a dish'), findsOneWidget);
    });
  });
}
