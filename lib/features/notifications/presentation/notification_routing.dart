import 'package:flutter/widgets.dart';

import '../domain/app_notification.dart';

/// Where a tapped notification goes, supplied by whichever shell is on screen.
///
/// The inbox validates a payload but cannot act on one: the destinations are
/// tabs, and only the shell knows which index is which — the admin shell's tabs
/// even change with the signed-in role. Rather than teach the notifications
/// feature about either shell, each shell hangs its own answer here.
///
/// Absent means the inbox is read-only, which is a legitimate state: the row
/// still marks itself read and still says what happened.
class NotificationRouting extends InheritedWidget {
  const NotificationRouting({
    super.key,
    required this.onFollow,
    required super.child,
  });

  /// Given the shell's own context, so `TabbedShell.selectTab` resolves.
  final void Function(BuildContext shell, NotificationPayload payload) onFollow;

  static NotificationRouting? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationRouting>();

  @override
  bool updateShouldNotify(NotificationRouting oldWidget) =>
      onFollow != oldWidget.onFollow;
}
