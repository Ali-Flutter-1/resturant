import 'package:flutter/material.dart';

import '../../shared/shell/tabbed_shell.dart';
import '../admin/presentation/admin_dashboard_screen.dart';
import '../admin/presentation/admin_menu_management_screen.dart';
import '../admin/presentation/admin_orders_screen.dart';
import '../admin/presentation/admin_reservations_screen.dart';

/// The staff-facing app, tabbed as the Figma dashboard labels it.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return TabbedShell(
      tabs: [
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
        ShellTab(
          label: 'Products',
          sfSymbol: 'shippingbox.fill',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          builder: (context) => const AdminMenuManagementScreen(),
        ),
        ShellTab(
          label: 'Reservations',
          sfSymbol: 'chair.fill',
          icon: Icons.event_seat_outlined,
          selectedIcon: Icons.event_seat,
          builder: (context) => const AdminReservationsScreen(),
        ),
      ],
    );
  }
}
