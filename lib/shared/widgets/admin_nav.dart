import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/haptics/app_haptics.dart';
import 'notifications_sheet.dart';
import '../../features/auth/auth_cubit.dart';

/// The header shared by every admin screen — wordmark centred, menu left,
/// notifications and sign-out right.
///
/// The admin tab bar itself lives in `TabbedShell`; screens no longer carry
/// their own, which is what keeps the native bar mounted across tab changes.
AppBar buildAdminAppBar(BuildContext context, {String? title}) {
  return AppBar(
    // The Figma header carries a hamburger, but no drawer is designed and
    // the tab bar already covers navigation — a control that leads nowhere
    // is worse than no control.
    automaticallyImplyLeading: false,
    title: Text(title ?? "T's Café"),
    actions: [
      IconButton(
        icon: const Icon(Icons.notifications_outlined),
        color: Theme.of(context).colorScheme.primary,
        onPressed: () => showNotificationsSheet(context),
        tooltip: 'Notifications',
      ),
      // Temporary, alongside the mock auth — the quickest way back to the
      // other role while testing.
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () {
          AppHaptics.commit();
          context.read<AuthCubit>().signOut();
        },
        tooltip: 'Sign out',
      ),
    ],
  );
}
