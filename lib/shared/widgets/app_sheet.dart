import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Presents [child] in a bottom sheet styled to the app.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg + 4),
      ),
    ),
    builder: (context) =>
        AppSheet(title: title, subtitle: subtitle, child: child),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.x3),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.surfaces.lineFirm,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x4,
                AppSpacing.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.texts.headlineLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(subtitle!, style: context.texts.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Flexible(child: child),
            const SizedBox(height: AppSpacing.x4),
          ],
        ),
      ),
    );
  }
}

/// A one-line confirmation, themed and consistent across the app.
void showAppSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline,
  bool isError = false,
}) {
  final colours = Theme.of(context).extension<OrderStateColors>()!;
  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : icon,
            size: 18,
            color: isError ? colours.overdue : colours.ready,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
