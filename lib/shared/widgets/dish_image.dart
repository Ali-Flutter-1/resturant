import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
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
///
/// [imageUrl] also accepts a local file path, so a photograph just taken with
/// the camera previews here before it has been uploaded anywhere. Detected by
/// scheme rather than by a second parameter: every caller already passes one
/// string, and which kind it is is knowable from the string itself.
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

  /// Whether this is something [Image.network] can fetch. `blob:` counts —
  /// that is what a web file picker hands back.
  static bool _isRemote(String value) =>
      value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('blob:') ||
      value.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    Widget image;
    if (url != null && url.isNotEmpty && !_isRemote(url)) {
      // A path from the camera or the gallery. Not available on web, where
      // picked files arrive as blob URLs and are handled by the branch below.
      image = kIsWeb
          ? _Placeholder(name: name)
          : Image.file(
              File(url),
              fit: fit,
              errorBuilder: (context, _, _) => _Placeholder(name: name),
            );
    } else if (url != null && url.isNotEmpty) {
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
          style: AppTypography.monogram(
            AppColors.neutral600.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (!shimmer) return field;
    return Shimmer(child: field);
  }
}
