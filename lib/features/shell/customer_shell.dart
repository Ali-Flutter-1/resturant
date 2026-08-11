import 'package:flutter/material.dart';

import '../../core/animations/page_transitions.dart';

import '../../shared/preview/sample_content.dart';
import '../menu/domain/dish.dart';
import '../../shared/shell/tabbed_shell.dart';
import '../about/presentation/about_contact_screen.dart';
import '../booking/presentation/book_table_screen.dart';
import '../checkout/presentation/checkout_screen.dart';
import '../discover/presentation/discover_screen.dart';
import '../menu/presentation/dish_details_screen.dart';
import '../menu/presentation/menu_screen.dart';
import '../orders/presentation/my_orders_screen.dart';

/// The customer-facing app.
///
/// Detail screens push into the *tab's* navigator — `Navigator.of(context)`
/// inside a tab resolves to that tab's nested navigator, which is exactly
/// what keeps the pushed route from covering the tab bar.
class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key});

  static void _openDish(BuildContext context, SampleDish dish) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => DishDetailsScreen(
          dish: dish,
          onBack: () => Navigator.of(context).pop(),
          // Adding no longer jumps to checkout — the item flies into the
          // cart and the user stays put, which is the point of the
          // animation. Checkout is reached from the cart icon.
          onOpenCart: () => _openCheckout(context),
        ),
      ),
    );
  }

  static void _openMenu(
    BuildContext context, {
    String? query,
    String? categorySlug,
  }) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => MenuScreen(
          initialQuery: query,
          initialCategorySlug: categorySlug,
          onOpenDish: (dish) => _openDish(context, _asPreview(dish)),
        ),
      ),
    );
  }

  static void _openCheckout(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => CheckoutScreen(
          onBack: () => Navigator.of(context).pop(),
          onPlaceOrder: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabbedShell(
      tabs: [
        ShellTab(
          label: 'Menu',
          sfSymbol: 'fork.knife',
          icon: Icons.restaurant_outlined,
          selectedIcon: Icons.restaurant,
          builder: (context) => DiscoverScreen(
            onOpenDish: (dish) => _openDish(context, dish),
            onOpenMenu: () => _openMenu(context),
            // Search and the filter button both open the full menu, which is
            // where filtering actually lives.
            onSearch: (query) => _openMenu(context, query: query),
            // A category circle opens the menu already filtered to it, rather
            // than only highlighting itself as it used to.
            onOpenCategory: (slug) => _openMenu(context, categorySlug: slug),
          ),
        ),
        ShellTab(
          label: 'Book',
          sfSymbol: 'calendar',
          icon: Icons.event_seat_outlined,
          selectedIcon: Icons.event_seat,
          builder: (context) => const BookTableScreen(),
        ),
        ShellTab(
          label: 'Orders',
          sfSymbol: 'list.bullet.rectangle',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (context) => MyOrdersScreen(
            // An empty history is a dead end otherwise. The menu is the
            // Discover tab's root, so this asks the shell to switch tabs
            // rather than pushing a second copy of it onto this one.
            onBrowseMenu: () => TabbedShell.selectTab(context, 0),
          ),
        ),
        ShellTab(
          label: 'Profile',
          sfSymbol: 'person',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (context) => const AboutContactScreen(),
        ),
      ],
    );
  }
}

/// Adapts an API [Dish] to the preview shape the dish detail screen still
/// expects.
///
/// Temporary scaffolding, and deliberately visible as such. The menu now comes
/// from the API but the detail screen has not been migrated yet, so this
/// converts between the two rather than blocking the menu on that work. It goes
/// away when `DishDetailsScreen` takes a [Dish].
SampleDish _asPreview(Dish dish) => SampleDish(
  name: dish.name,
  description: dish.description,
  price: dish.price,
  tag: dish.dietaryTag,
  imageUrl: dish.imageUrl,
);
