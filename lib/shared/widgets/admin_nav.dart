import 'package:flutter/material.dart';

import '../../features/notifications/presentation/notifications_screen.dart';

/// The header shared by every admin screen — wordmark centred, notifications
/// right.
///
/// The admin tab bar itself lives in `TabbedShell`; screens no longer carry
/// their own, which is what keeps the native bar mounted across tab changes.
///
/// Signing out is **not** here. It belongs in one place — the Profile tab's
/// account panel — so there is a single answer to "where do I sign out?". This
/// header carried a second one from the mock-auth days, which meant a
/// destructive action sat one mis-tap from the notification bell on every admin
/// screen.
AppBar buildAdminAppBar(BuildContext context, {String? title}) {
  return AppBar(
    // The Figma header carries a hamburger, but no drawer is designed and
    // the tab bar already covers navigation — a control that leads nowhere
    // is worse than no control.
    automaticallyImplyLeading: false,
    title: Text(title ?? "T's Café"),
    actions: [NotificationBell(onOpen: () => openNotifications(context))],
  );
}
