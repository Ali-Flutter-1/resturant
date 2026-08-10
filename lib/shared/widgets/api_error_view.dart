import 'package:flutter/material.dart';

import '../../core/animations/reveal.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// What a screen shows when a request failed.
///
/// The message is [ApiFailure.message] verbatim — the API's own words where it
/// sent any, a plain-English fallback where it didn't. Nothing here composes
/// error text, and no status code or exception name reaches the screen.
///
/// "Try again" appears only when retrying could plausibly work. Offering it for
/// a rejected password would invite the user to fail identically a second time.
class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.failure, this.onRetry});

  final ApiFailure failure;
  final Future<void> Function()? onRetry;

  /// A glyph matched to the cause, so the shape of the problem reads before the
  /// sentence does.
  IconData get _icon => switch (failure.kind) {
    ApiFailureKind.offline => Icons.wifi_off_outlined,
    ApiFailureKind.timeout ||
    ApiFailureKind.unreachable => Icons.cloud_off_outlined,
    ApiFailureKind.notFound => Icons.search_off,
    ApiFailureKind.unauthorised => Icons.lock_outline,
    _ => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: AppIconSize.hero,
              color: context.surfaces.inkSoft,
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: context.texts.bodyLarge,
            ),
            if (onRetry != null && failure.isRetryable) ...[
              const SizedBox(height: AppSpacing.x5),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: AppIconSize.md),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ).reveal(),
    );
  }
}
