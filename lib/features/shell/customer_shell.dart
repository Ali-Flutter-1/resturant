import 'package:flutter/material.dart';

import '../../core/animations/page_transitions.dart';

import '../menu/domain/dish.dart';
import '../../shared/shell/tabbed_shell.dart';
import '../about/presentation/about_contact_screen.dart';
import '../auth/presentation/profile_screen.dart';
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

  static void _openDish(BuildContext context, Dish dish) {
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
          onOpenDish: (dish) => _openDish(context, dish),
        ),
      ),
    );
  }

  static void _openCheckout(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (context) => CheckoutScreen(
          onBack: () => Navigator.of(context).pop(),
          // Back to the tab root, then over to Orders: the order now exists, and
          // the tracker is where the customer wants to be looking at it.
          onPlaceOrder: (_) {
            Navigator.of(context).popUntil((r) => r.isFirst);
            TabbedShell.selectTab(context, 2);
          },
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
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          builder: (context) => const BookTableScreen(),
        ),
        ShellTab(
          label: 'Orders',
          sfSymbol: 'list.bullet.rectangle',
          icon: Icons.list_alt_outlined,
          selectedIcon: Icons.list_alt,
          builder: (context) => MyOrdersScreen(
            onOpenCheckout: () => _openCheckout(context),
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
          builder: (context) => ProfileScreen(
            // About-and-contact is pushed rather than being the tab itself: the
            // tab is the person's account, and the contact form is one thing
            // they might want from it.
            onGetInTouch: () => Navigator.of(context).push(
              AppPageRoute<void>(builder: (_) => const AboutContactScreen()),
            ),
          ),
        ),
      ],
    );
  }
}
