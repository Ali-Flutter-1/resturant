import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Stands in for a dish photograph.
///
/// The Figma file's food photography is not available as exported assets, and
/// inventing images would be worse than admitting their absence. This renders
/// a warm tinted field carrying the dish's initial, and swaps to the real
/// photograph the moment [imageUrl] is supplied by the API.
class DishImage extends StatelessWidget {
  const DishImage({
    super.key,
    required this.name,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  final String name;
  final String? imageUrl;
  final BoxFit fit;

  /// Set on both the card and the detail screen to fly the image between them.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    Widget image;
    if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: fit,
        // Cross-fade from the shimmer rather than popping in.
        frameBuilder: (context, child, frame, wasSyncLoaded) {
          if (wasSyncLoaded) return child;
          return AnimatedSwitcher(
            duration: context.motion.fade(Motion.base),
            child: frame == null
                ? _Placeholder(name: name, shimmer: true)
                : child,
          );
        },
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _Placeholder(name: name, shimmer: true),
        errorBuilder: (context, _, _) => _Placeholder(name: name),
      );
    } else {
      image = _Placeholder(name: name);
    }

    if (heroTag == null) return image;
    return Hero(
      tag: heroTag!,
      // Keep the flight clipped to the destination's shape rather than
      // letting a square image escape its rounded card mid-flight.
      flightShuttleBuilder: (_, animation, _, _, _) => image,
      child: image,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, this.shimmer = false});

  final String name;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    // Deterministic tint per dish, so a grid doesn't read as one flat block.
    final seed = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final tints = [
      AppColors.crimson100,
      AppColors.neutral100,
      AppColors.crimson50,
      AppColors.neutral50,
    ];
    final base = tints[seed % tints.length];

    final field = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, AppColors.neutral200.withValues(alpha: 0.6)],
        ),
      ),
      child: Center(
        child: Text(
          name.characters.first.toUpperCase(),
          style: AppTypography.money(
            AppColors.neutral600.withValues(alpha: 0.5),
            size: 34,
            tabular: false,
          ),
        ),
      ),
    );

    if (!shimmer) return field;
    return Shimmer(child: field);
  }
}
