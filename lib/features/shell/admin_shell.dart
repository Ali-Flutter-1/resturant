import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/animations/page_transitions.dart';

import '../../shared/shell/tabbed_shell.dart';
import '../admin/presentation/admin_dashboard_screen.dart';
import '../admin/presentation/admin_menu_management_screen.dart';
import '../admin/presentation/admin_orders_screen.dart';
import '../admin/presentation/admin_reservations_screen.dart';
import '../admin/presentation/admin_contact_screen.dart';
import '../auth/auth_cubit.dart';
import '../auth/presentation/profile_screen.dart';

/// The staff-facing app, tabbed as the Figma dashboard labels it.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once here rather than per tab: `canManageVenue` is what separates an
    // administrator from a staff member, and it was declared and never enforced
    // anywhere until now.
    final canManageVenue =
        context.select((AuthCubit c) => c.state.role?.canManageVenue) ?? false;

    return TabbedShell(
      tabs: [
        // Analytics is takings and trends — the owner's view of the business,
        // not the kitchen's. Staff work the queue; what the venue earned is not
        // theirs to see.
        if (canManageVenue)
          ShellTab(
            label: 'Analytics',
            sfSymbol: 'chart.bar.fill',
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights,
            builder: (context) => const AdminDashboardScreen(),
          ),
        ShellTab(
          label: 'Orders',
          sfSymbol: 'list.bullet.rectangle.fill',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          builder: (context) => const AdminOrdersScreen(),
        ),
        // Managing the menu is `canManageVenue` work. A staff member reaching
        // this tab could open every control on it and be refused by the API on
        // each one — a screen you can enter and not use is worse than one that
        // isn't there.
        if (canManageVenue)
          ShellTab(
            label: 'Products',
            sfSymbol: 'shippingbox.fill',
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2,
            builder: (context) => const AdminMenuManagementScreen(),
          ),
        // Staff and admin had no way to reach their own account at all — no
        // profile, and sign-out was buried on the customers' About screen,
        // which this shell never shows.
        ShellTab(
          label: 'Reservations',
          sfSymbol: 'chair.fill',
          icon: Icons.event_seat_outlined,
          selectedIcon: Icons.event_seat,
          builder: (context) => const AdminReservationsScreen(),
        ),
        ShellTab(
          label: 'Profile',
          sfSymbol: 'person',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (context) => ProfileScreen(
            // Admin only. The inbox lives under `/admin/contact`, which the
            // docs group with the administrator's routes rather than the
            // kitchen's.
            onOpenMessages: canManageVenue
                ? () => Navigator.of(context).push(
                    AppPageRoute<void>(
                      builder: (_) => const AdminContactScreen(),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
